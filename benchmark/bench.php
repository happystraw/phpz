#!/usr/bin/env php
<?php
declare(strict_types=1);

$options = getopt('', ['iterations:', 'samples:', 'filter:', 'impls:', 'json:', 'seed:', 'list', 'help']);
if (isset($options['help'])) {
    echo <<<TXT
    Usage: php bench.php [--iterations=N] [--samples=N] [--filter=REGEX] [--impls=c,cpp,zig] [--json=FILE] [--seed=N] [--list]

    Each benchmark runs a generated loop with direct calls. Every round runs all
    implementations once in a shuffled order; results are medians across rounds.

    TXT;
    exit(0);
}

$iterations = max(1, (int)($options['iterations'] ?? 200_000));
$samples = max(3, (int)($options['samples'] ?? 15));
$filter = $options['filter'] ?? null;
$seed = (int)($options['seed'] ?? 1);
$impls = array_values(array_filter(explode(',', $options['impls'] ?? 'c,cpp,zig')));
$known = [
    'c' => ['ext' => 'bench_c', 'class' => 'BenchCPoint'],
    'cpp' => ['ext' => 'bench_cpp', 'class' => 'BenchCppPoint'],
    'zig' => ['ext' => 'bench_zig', 'class' => 'BenchZigPoint'],
];
foreach ($impls as $impl) {
    if (!isset($known[$impl])) {
        fwrite(STDERR, "Unknown implementation '$impl'\n");
        exit(1);
    }
    if (!extension_loaded($known[$impl]['ext'])) {
        fwrite(STDERR, "Extension {$known[$impl]['ext']} is not loaded\n");
        exit(1);
    }
}

// `scale` divides the iteration count for heavier bodies. Setup runs once per
// generated loop; `{f}` is the function prefix, `{C}` the point class and
// `$__i` the loop counter.
$benchmarks = [
    'loop' => ['desc' => 'Loop overhead (no call)', 'body' => ''],
    'empty' => ['desc' => 'Empty function call', 'body' => '{f}_empty();'],
    'add' => ['desc' => 'add(int, int): int', 'setup' => '$a = 40; $b = 2;', 'body' => '{f}_add($a, $b);'],
    'muladd' => ['desc' => 'muladd(float x3): float', 'setup' => '$a = 1.5; $b = 2.0; $c = 0.25;', 'body' => '{f}_muladd($a, $b, $c);'],
    'parse_multi' => [
        'desc' => '8 params, typed/fast ZPP',
        'setup' => '$arr = range(1, 1000); $obj = new stdClass();',
        'body' => '{f}_parse_multi(42, "hello", 3.14, true, $arr, $obj, "mixed", 99);',
    ],
    'parse_multi_pp' => [
        'desc' => '8 params, zend_parse_parameters',
        'setup' => '$arr = range(1, 1000); $obj = new stdClass();',
        'body' => '{f}_parse_multi_pp(42, "hello", 3.14, true, $arr, $obj, "mixed", 99);',
    ],
    'str_len' => ['desc' => 'str_len(string): int', 'setup' => '$s = str_repeat("x", 64);', 'body' => '{f}_str_len($s);'],
    'int_to_string' => ['desc' => 'int_to_string(int): string', 'setup' => '$n = 123456789;', 'body' => '{f}_int_to_string($n);'],
    'str_upper_16' => ['desc' => 'str_upper 16 B (alloc + loop)', 'setup' => '$s = str_repeat("abcdefgh", 2);', 'body' => '{f}_str_upper($s);'],
    'str_upper_4k' => ['desc' => 'str_upper 4 KiB', 'scale' => 20, 'setup' => '$s = str_repeat("abcdefgh", 512);', 'body' => '{f}_str_upper($s);'],
    'array_sum_packed' => ['desc' => 'Packed array sum, 1k', 'scale' => 20, 'setup' => '$arr = range(1, 1000);', 'body' => '{f}_array_sum_fast($arr);'],
    'array_sum_parse' => ['desc' => 'Packed array sum, 1k (ZPP "a")', 'scale' => 20, 'setup' => '$arr = range(1, 1000);', 'body' => '{f}_array_sum_parse($arr);'],
    'array_sum_assoc' => [
        'desc' => 'Assoc array keys+values, 1k',
        'scale' => 20,
        'setup' => '$arr = []; for ($k = 0; $k < 1000; $k++) { $arr["k$k"] = $k; }',
        'body' => '{f}_array_sum_assoc($arr);',
    ],
    'array_build' => ['desc' => 'Build packed array, 1k', 'scale' => 20, 'setup' => '$n = 1000;', 'body' => '{f}_array_build($n);'],
    'hash_lookup' => [
        'desc' => 'Hash lookup (string key)',
        'setup' => '$arr = []; for ($k = 0; $k < 1000; $k++) { $arr["k$k"] = $k; } $key = "k500";',
        'body' => '{f}_hash_lookup($arr, $key);',
    ],
    'array_identity' => ['desc' => 'Return arg array (refcount)', 'setup' => '$arr = range(1, 100);', 'body' => '{f}_array_identity($arr);'],
    'globals' => ['desc' => 'Module globals read/write', 'body' => '{f}_counter();'],
    'callback' => ['desc' => 'Call a PHP closure from native', 'setup' => '$fn = static fn ($x) => $x;', 'body' => '{f}_invoke($fn, $__i);'],
    'object_new' => ['desc' => 'new Point + destroy', 'body' => 'new {C}(1.0, 2.0);'],
    'method_call' => ['desc' => 'Method call, native read', 'setup' => '$p = new {C}(3.0, 4.0);', 'body' => '$p->length();'],
    'method_write' => ['desc' => 'Method call, native write', 'setup' => '$p = new {C}(3.0, 4.0);', 'body' => '$p->translate(0.5, -0.5);'],
    'exception' => ['desc' => 'Throw + catch exception', 'scale' => 4, 'body' => 'try { {f}_throw(1); } catch (Exception $e) {}'],
    'split' => [
        'desc' => 'split 64 fields (E2E, alloc heavy)',
        'scale' => 20,
        'setup' => '$line = implode(",", array_map(fn ($i) => "field$i", range(1, 64)));',
        'body' => '{f}_split($line, ",");',
    ],
    'pipeline' => [
        'desc' => 'split + upper + len per field (E2E)',
        'scale' => 50,
        'setup' => '$line = implode(",", array_map(fn ($i) => "field$i", range(1, 64)));',
        'body' => '$sum = 0; foreach ({f}_split($line, ",") as $part) { $sum += {f}_str_len({f}_str_upper($part)); }',
    ],
    'sustained' => [
        'desc' => 'Mixed calls, sustained',
        'scale' => 2,
        'setup' => '$s = "payload"; $p = new {C}(1.0, 1.0); $arr = range(1, 8);',
        'body' => '{f}_add($__i, 1); {f}_str_len($s); $p->length(); {f}_array_identity($arr);',
    ],
];

if (isset($options['list'])) {
    foreach ($benchmarks as $name => $bench) printf("%-20s %s\n", $name, $bench['desc']);
    exit(0);
}
if ($filter !== null) {
    $benchmarks = array_filter($benchmarks, fn ($name) => preg_match("/$filter/", $name) === 1, ARRAY_FILTER_USE_KEY);
}

function compileLoop(array $bench, string $prefix, string $class): Closure
{
    $replace = ['{f}' => $prefix, '{C}' => $class];
    $setup = strtr($bench['setup'] ?? '', $replace);
    $body = strtr($bench['body'], $replace);
    return eval("return static function (int \$__n): void { $setup for (\$__i = 0; \$__i < \$__n; \$__i++) { $body } };");
}

function cpuNanos(): int
{
    $usage = getrusage();
    return ($usage['ru_utime.tv_sec'] + $usage['ru_stime.tv_sec']) * 1_000_000_000
        + ($usage['ru_utime.tv_usec'] + $usage['ru_stime.tv_usec']) * 1_000;
}

function quantile(array $values, float $q): float
{
    sort($values);
    $pos = (count($values) - 1) * $q;
    $low = (int)floor($pos);
    $high = (int)ceil($pos);
    return $values[$low] + ($values[$high] - $values[$low]) * ($pos - $low);
}

function summarize(array $values): array
{
    $mean = array_sum($values) / count($values);
    $variance = 0.0;
    foreach ($values as $value) $variance += ($value - $mean) ** 2;
    return [
        'median' => quantile($values, 0.5),
        'p25' => quantile($values, 0.25),
        'p75' => quantile($values, 0.75),
        'min' => min($values),
        'cv' => $mean > 0 ? sqrt($variance / max(1, count($values) - 1)) / $mean : 0.0,
    ];
}

$results = [];
$memoryStart = memory_get_usage();
foreach ($benchmarks as $name => $bench) {
    $n = max(1, intdiv($iterations, $bench['scale'] ?? 1));
    $loops = [];
    foreach ($impls as $impl) {
        $loops[$impl] = compileLoop($bench, $known[$impl]['ext'], $known[$impl]['class']);
        $loops[$impl](max(1, intdiv($n, 5)));
    }
    $raw = array_fill_keys($impls, ['ns' => [], 'cpu' => [], 'mem' => []]);
    for ($round = 0; $round < $samples; $round++) {
        $order = $impls;
        mt_srand($seed + $round * 7919 + crc32($name));
        shuffle($order);
        foreach ($order as $impl) {
            gc_collect_cycles();
            $before = memory_get_usage();
            $cpu = cpuNanos();
            $start = hrtime(true);
            $loops[$impl]($n);
            $elapsed = hrtime(true) - $start;
            $raw[$impl]['cpu'][] = (cpuNanos() - $cpu) / $n;
            $raw[$impl]['ns'][] = $elapsed / $n;
            $raw[$impl]['mem'][] = memory_get_usage() - $before;
        }
    }
    foreach ($impls as $impl) {
        $results[$name][$impl] = [
            'iterations' => $n,
            'ns' => summarize($raw[$impl]['ns']),
            'cpu_ns' => summarize($raw[$impl]['cpu']),
            'memory_delta_max' => max($raw[$impl]['mem']),
            'samples_ns' => $raw[$impl]['ns'],
            'samples_cpu_ns' => $raw[$impl]['cpu'],
        ];
    }
}

// Ratios are against C. A difference counts only when the medians differ by
// more than 3% and the interquartile ranges do not overlap.
function verdict(array $base, array $other): string
{
    $ratio = $other['median'] / $base['median'];
    $overlap = $other['p25'] <= $base['p75'] && $base['p25'] <= $other['p75'];
    if (abs(1 - $ratio) < 0.03 || $overlap) return sprintf('%.2fx ~', $ratio);
    return sprintf('%.2fx %s', $ratio, $ratio < 1 ? 'faster' : 'slower');
}

$cpuModel = '';
if (is_readable('/proc/cpuinfo') && preg_match('/model name\s*:\s*(.+)/', (string)file_get_contents('/proc/cpuinfo'), $m)) {
    $cpuModel = trim($m[1]);
} elseif (PHP_OS_FAMILY === 'Darwin') {
    $cpuModel = trim((string)shell_exec('sysctl -n machdep.cpu.brand_string 2>/dev/null'));
}
$meta = [
    'date' => date(DATE_ATOM),
    'php' => PHP_VERSION,
    'zts' => (bool) PHP_ZTS,
    'debug' => (bool) PHP_DEBUG,
    'opcache' => function_exists('opcache_get_status') && (opcache_get_status(false)['opcache_enabled'] ?? false),
    'os' => php_uname(),
    'cpu' => $cpuModel,
    'iterations' => $iterations,
    'samples' => $samples,
    'seed' => $seed,
    'toolchains' => [
        'cc' => getenv('BENCH_CC_VERSION') ?: null,
        'cxx' => getenv('BENCH_CXX_VERSION') ?: null,
        'zig' => getenv('BENCH_ZIG_VERSION') ?: null,
        'cflags' => getenv('BENCH_CFLAGS') ?: null,
        'zig_optimize' => getenv('BENCH_ZIG_OPTIMIZE') ?: null,
    ],
    'memory_growth' => memory_get_usage() - $memoryStart,
];

printf("\nPHP %s %s%s | %s | %d rounds, shuffled order\n", PHP_VERSION, PHP_ZTS ? 'ZTS' : 'NTS', PHP_DEBUG ? ' debug' : '', $cpuModel ?: php_uname('m'), $samples);
$header = sprintf('  %-34s', 'Benchmark (median ns/op, IQR)');
foreach ($impls as $impl) $header .= sprintf(' %20s', strtoupper($impl));
foreach ($impls as $impl) if ($impl !== 'c' && in_array('c', $impls, true)) $header .= sprintf(' %15s', strtoupper($impl) . '/C');
echo $header, "\n", str_repeat('-', strlen($header)), "\n";
foreach ($results as $name => $byImpl) {
    $line = sprintf('  %-34s', $benchmarks[$name]['desc']);
    foreach ($impls as $impl) {
        $s = $byImpl[$impl]['ns'];
        $line .= sprintf(' %11.1f ±%7.1f', $s['median'], $s['p75'] - $s['p25']);
    }
    foreach ($impls as $impl) {
        if ($impl !== 'c' && isset($byImpl['c'])) $line .= sprintf(' %15s', verdict($byImpl['c']['ns'], $byImpl[$impl]['ns']));
    }
    echo $line, "\n";
}
echo "\n  '~' marks differences within noise (<3% or overlapping IQR). Loop overhead is included in every row.\n";
printf("  Request memory growth across the run, including stored samples: %d bytes\n\n", $meta['memory_growth']);

if (isset($options['json'])) {
    file_put_contents($options['json'], json_encode(['meta' => $meta, 'results' => $results], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");
    echo "  Raw results: {$options['json']}\n";
}
