#!/usr/bin/env php
<?php

$iterations = 1_000_000;
foreach ($argv as $arg) {
    if (str_starts_with($arg, '--iterations=')) {
        $iterations = (int)substr($arg, strlen('--iterations='));
    }
}

$required = ['bench_c', 'bench_zig'];
$missing = array_filter($required, fn($ext) => !extension_loaded($ext));
if ($missing) {
    fprintf(STDERR, "ERROR: Missing extensions: %s\n", implode(', ', $missing));
    exit(1);
}

$array1k = range(1, 1000);
$obj = new stdClass();

$benchmarks = [
    'empty' => [
        'desc' => 'Empty function call',
        'args' => [],
    ],
    'parse_multi' => [
        'desc' => 'Parse 8 params (macro/fast)',
        'args' => [42, 'hello', 3.14, true, $array1k, $obj, 'mixed', 99],
    ],
    'parse_multi_pp' => [
        'desc' => 'Parse 8 params (parse/zpp)',
        'args' => [42, 'hello', 3.14, true, $array1k, $obj, 'mixed', 99],
    ],
    'array_sum_fast' => [
        'desc' => 'Array sum 1k (macro/fast)',
        'args' => [$array1k],
    ],
    'array_sum_parse' => [
        'desc' => 'Array sum 1k (parse/zpp)',
        'args' => [$array1k],
    ],
];

// Warmup
$warmup = min($iterations, 1000);
foreach (['bench_c', 'bench_zig'] as $prefix) {
    foreach ($benchmarks as $name => $bench) {
        $func = $prefix . '_' . $name;
        for ($i = 0; $i < $warmup; $i++) {
            $func(...$bench['args']);
        }
    }
}

// Run
$results = [];
foreach ($benchmarks as $name => $bench) {
    foreach (['bench_c', 'bench_zig'] as $prefix) {
        $func = $prefix . '_' . $name;
        $args = $bench['args'];

        $start = hrtime(true);
        for ($i = 0; $i < $iterations; $i++) {
            $func(...$args);
        }
        $elapsed = hrtime(true) - $start;

        $results[$name][$prefix] = [
            'ns_per_call' => $elapsed / $iterations,
        ];
    }
}

// Print
$line = str_repeat("-", 90);

printf("\n");
printf("  PHP Extension: C (bench_c) vs Zig/phpz (bench_zig)\n");
printf("%s\n", $line);
printf("  %-32s %8s  %10s  %10s  %-4s  %9s\n", 'Benchmark', 'Iters', 'C ns/call', 'Zig ns/call', 'Win', 'Diff');
printf("%s\n", $line);

$total_c = 0;
$total_z = 0;

foreach ($benchmarks as $name => $bench) {
    $c = $results[$name]['bench_c']['ns_per_call'];
    $z = $results[$name]['bench_zig']['ns_per_call'];
    $ratio = $c > 0 ? $z / $c : 0;
    $winner = $ratio < 1.0 ? 'Zig' : ($ratio > 1.0 ? 'C' : '-');
    $pct = abs(1.0 - $ratio) * 100;
    $d = $ratio < 1.0 ? 'faster' : 'slower';
    $diff = $winner === '-' ? '-' : sprintf('%5.1f%% %s', $pct, $d);

    printf("  %-32s %8d  %10.1f  %10.1f  %-4s  %9s\n",
        $bench['desc'], $iterations, $c, $z, $winner, $diff);

    $total_c += $c;
    $total_z += $z;
}

printf("%s\n", $line);
$tr = $total_z / $total_c;
$tw = $tr < 1.0 ? 'Zig' : ($tr > 1.0 ? 'C' : '-');
$tp = abs(1.0 - $tr) * 100;
$td = $tw === '-' ? '-' : sprintf('%.1f%% %s', $tp, $tr < 1.0 ? 'faster' : 'slower');
printf("  %-32s %8s  %10.1f  %10.1f  %-4s  %9s\n",
    'TOTAL', '', $total_c, $total_z, $tw, $td);
printf("%s\n\n", $line);
