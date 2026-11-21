#!/usr/bin/env php
<?php

declare(strict_types=1);

require __DIR__ . '/suite.php';

const IMPLEMENTATIONS = ['c' => 'C', 'phpx' => 'PHPX', 'zig' => 'PHPZ'];
const ORDERS = ['c phpx zig', 'c zig phpx', 'phpx c zig', 'phpx zig c', 'zig c phpx', 'zig phpx c'];
const TABLE_ROW = "%-16s %s   %s   %s   %21s   %21s   %21s\n";

function worker(array $args): void
{
    [$implementation, $case, $count] = $args;
    $module = 'bench_' . $implementation;
    if (!extension_loaded($module)) {
        throw new RuntimeException("$module did not load");
    }
    $cases = benchmarkCases();
    if ($case === '--check') {
        verifyCases($cases);
        echo json_encode(array_keys($cases), JSON_THROW_ON_ERROR);
        return;
    }

    [$expression, $input] = $cases[$case];
    $iterations = (int) $count;
    // Expressions are fixed in suite.php. Each iteration uses a direct call.
    $loop = eval('declare(strict_types=1); return static function (int $iterations, mixed $input): void {
        for ($i = 0; $i < $iterations; $i++) { ' . $expression . '; }
    };');
    $loop(max(100, intdiv($iterations, 5)), $input);

    $start = hrtime(true);
    $loop($iterations, $input);
    echo json_encode(['elapsed_ns' => hrtime(true) - $start], JSON_THROW_ON_ERROR);
}

function sample(string $directory, string $implementation, string $case, int $iterations): array
{
    $command = [
        PHP_BINARY, '-n', '-d', 'opcache.enable_cli=0', '-d', 'opcache.jit=disable',
        '-d', 'display_errors=stderr', '-d', 'log_errors=0',
        '-d', "extension=$directory/bench_$implementation.so",
        __FILE__, '--worker', $implementation, $case, (string) $iterations,
    ];
    $process = proc_open($command, [1 => ['pipe', 'w'], 2 => ['redirect', 1]], $pipes);
    if (!is_resource($process)) {
        throw new RuntimeException('Cannot start the benchmark PHP process');
    }

    // Stream stderr into stdout so the worker cannot fill two pipes.
    // Workers emit only a single JSON record or an error.
    $output = stream_get_contents($pipes[1]);
    fclose($pipes[1]);
    if (proc_close($process) !== 0) {
        throw new RuntimeException("$implementation $case failed: " . trim($output));
    }
    try {
        return json_decode($output, true, flags: JSON_THROW_ON_ERROR);
    } catch (JsonException $error) {
        throw new RuntimeException("$implementation $case produced invalid output: " . trim($output), previous: $error);
    }
}

function median(array $values): float
{
    sort($values, SORT_NUMERIC);
    $middle = intdiv(count($values), 2);
    return count($values) % 2 ? $values[$middle] : ($values[$middle - 1] + $values[$middle]) / 2;
}

function pairedRatio(array $rounds, string $numerator, string $denominator): array
{
    $ratios = array_map(
        static fn (array $round): float => $round['elapsed_ns'][$numerator] / $round['elapsed_ns'][$denominator],
        $rounds,
    );
    $resamples = [];
    $count = count($ratios);
    for ($i = 0; $i < 5000; $i++) {
        $resample = [];
        for ($j = 0; $j < $count; $j++) {
            $resample[] = $ratios[mt_rand(0, $count - 1)];
        }
        $resamples[] = median($resample);
    }
    sort($resamples, SORT_NUMERIC);
    return ['median' => median($ratios), 'ci95' => [$resamples[125], $resamples[4874]]];
}

function measure(string $directory, string $case, int $targetNs, array $orders): array
{
    $iterations = 1000;
    do {
        $fastest = PHP_INT_MAX;
        foreach (array_keys(IMPLEMENTATIONS) as $implementation) {
            $elapsed = sample($directory, $implementation, $case, $iterations)['elapsed_ns'];
            $fastest = min($fastest, $elapsed);
        }
        if ($fastest >= $targetNs) {
            break;
        }
        $iterations *= max(2, min(16, (int) ceil($targetNs / max(1, $fastest))));
    } while ($iterations <= 100_000_000);
    if ($fastest < $targetNs) {
        throw new RuntimeException("Could not calibrate $case");
    }

    $rounds = [];
    foreach ($orders as $order) {
        $order = explode(' ', $order);
        $elapsed = [];
        foreach ($order as $implementation) {
            $elapsed[$implementation] = sample($directory, $implementation, $case, $iterations)['elapsed_ns'];
        }
        $rounds[] = ['order' => $order, 'elapsed_ns' => $elapsed];
    }

    $medians = [];
    foreach (array_keys(IMPLEMENTATIONS) as $implementation) {
        $medians[$implementation] = median(array_map(
            static fn (array $round): float => $round['elapsed_ns'][$implementation] / $iterations,
            $rounds,
        ));
    }
    return [
        'iterations' => $iterations,
        'median_ns_per_op' => $medians,
        'ratios' => [
            'PHPX/C' => pairedRatio($rounds, 'phpx', 'c'),
            'PHPZ/C' => pairedRatio($rounds, 'zig', 'c'),
            'PHPZ/PHPX' => pairedRatio($rounds, 'zig', 'phpx'),
        ],
        'rounds' => $rounds,
    ];
}

function timeColumn(string $value, string $marker = '  '): string
{
    return sprintf('%10s %s', $value, $marker);
}

function printResult(string $case, array $result): void
{
    $medians = $result['median_ns_per_op'];
    $fastest = min($medians);
    $markFastest = $fastest !== max($medians);
    $times = array_map(static function (float $time) use ($fastest, $markFastest): string {
        $marker = $markFastest && $time === $fastest ? '⚡' : '  ';
        return timeColumn(sprintf('%.2f', $time), $marker);
    }, $medians);
    $ratios = array_map(
        static fn (array $ratio): string => sprintf('%.2fx [%.2f, %.2f]', $ratio['median'], ...$ratio['ci95']),
        $result['ratios'],
    );
    printf(TABLE_ROW, $case, $times['c'], $times['zig'], $times['phpx'],
        $ratios['PHPZ/C'], $ratios['PHPX/C'], $ratios['PHPZ/PHPX']);
}

function integerOption(array $options, string $name, int $default, int $min, int $max): int
{
    $value = filter_var($options[$name] ?? $default, FILTER_VALIDATE_INT, [
        'options' => ['min_range' => $min, 'max_range' => $max],
    ]);
    if ($value === false) {
        throw new InvalidArgumentException("--$name must be an integer between $min and $max");
    }
    return $value;
}

function run(): void
{
    $options = getopt('', ['rounds:', 'seed:', 'target-ms:', 'filter:', 'json:', 'check', 'help'], $rest);
    if (isset($options['help'])) {
        echo "Usage: ./run.sh [--rounds=36] [--target-ms=50] [--seed=1] [--filter=substring] [--json=FILE] [--check]\n";
        return;
    }
    if ($rest !== count($_SERVER['argv']) || count($options) !== $rest - 1) {
        throw new InvalidArgumentException('Use a supported option once, with --name=value for options that take a value');
    }
    $directory = getenv('BENCH_MODULES');
    if ($directory === false) {
        throw new RuntimeException('Start the benchmark with benchmark/run.sh');
    }

    $roundCount = integerOption($options, 'rounds', 36, 6, 600);
    $targetMs = integerOption($options, 'target-ms', 50, 1, 1000);
    $seed = integerOption($options, 'seed', 1, 0, 2147483647);
    if ($roundCount % count(ORDERS) !== 0) {
        throw new InvalidArgumentException('--rounds must be divisible by six');
    }

    foreach (IMPLEMENTATIONS as $implementation => $label) {
        $cases = sample($directory, $implementation, '--check', 1);
        fwrite(STDERR, "$label passed the shared checks\n");
    }
    if (isset($options['check'])) {
        return;
    }

    if (isset($options['filter'])) {
        $filter = $options['filter'];
        if (!is_string($filter)) {
            throw new InvalidArgumentException('--filter must be supplied once');
        }
        $cases = array_values(array_filter($cases, static fn (string $case): bool => str_contains($case, $filter)));
    }
    if ($cases === []) {
        throw new InvalidArgumentException('No cases matched --filter');
    }

    mt_srand($seed);
    sort($cases, SORT_NATURAL);
    $results = [];
    $timeHeading = str_pad('Median time (ns/op)', 45, ' ', STR_PAD_BOTH);
    $ratioHeading = str_pad('Paired time ratio (95% CI)', 69, ' ', STR_PAD_BOTH);
    printf("%17s%s   %s\n", '', $timeHeading, rtrim($ratioHeading));
    printf(TABLE_ROW, 'Benchmark', timeColumn('C'), timeColumn('PHPZ(ZIG)'), timeColumn('PHPX(C++)'),
        'PHPZ / C', 'PHPX / C', 'PHPZ / PHPX');
    foreach ($cases as $case) {
        $orders = array_merge(...array_fill(0, intdiv($roundCount, count(ORDERS)), ORDERS));
        shuffle($orders);
        $results[$case] = measure($directory, $case, $targetMs * 1_000_000, $orders);
        printResult($case, $results[$case]);
    }

    $path = $options['json'] ?? __DIR__ . '/results/latest.json';
    if (!is_string($path) || $path === '') {
        throw new InvalidArgumentException('--json must be supplied once with a file path');
    }
    $reportDirectory = dirname($path);
    if (!is_dir($reportDirectory) && !mkdir($reportDirectory, 0777, true) && !is_dir($reportDirectory)) {
        throw new RuntimeException("Cannot create $reportDirectory");
    }
    $metadata = json_decode(file_get_contents($directory . '/build.json'), true, flags: JSON_THROW_ON_ERROR);
    $cpuInfo = file_get_contents('/proc/cpuinfo');
    preg_match('/^model name\s*:\s*(.+)$/m', $cpuInfo, $cpuModel);
    $report = [
        'metadata' => $metadata + [
            'php' => PHP_VERSION, 'zts' => (bool) PHP_ZTS, 'debug' => (bool) PHP_DEBUG,
            'system' => php_uname(), 'date' => gmdate(DATE_ATOM),
            'cpu' => $cpuModel[1] ?? null, 'cpu_core' => getenv('BENCH_CPU'),
            'rounds' => $roundCount, 'target_ms' => $targetMs, 'seed' => $seed,
        ],
        'results' => $results,
    ];
    if (file_put_contents($path, json_encode($report, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR) . "\n") === false) {
        throw new RuntimeException("Cannot write $path");
    }
    echo "Raw samples written to $path\n";
}

try {
    if (($_SERVER['argv'][1] ?? null) === '--worker') {
        worker(array_slice($_SERVER['argv'], 2));
    } else {
        run();
    }
} catch (Throwable $error) {
    fwrite(STDERR, $error->getMessage() . "\n");
    exit(1);
}
