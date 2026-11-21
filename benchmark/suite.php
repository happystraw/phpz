<?php

declare(strict_types=1);

function pipeline(string $record): int
{
    $length = 0;
    foreach (bench_split($record) as $field) {
        $length += bench_length(bench_upper($field));
    }
    return $length;
}

function benchmarkCases(): array
{
    $cases = [
        'call' => ['bench_call()', null, null],
        'callback' => ['bench_invoke($input, 41)', static fn (int $n): int => $n + 1, 42],
        'args/omitted' => ['bench_args(7, "abc", 0.25, true)', null, 116],
        'args/null' => ['bench_args(7, "abc", 0.25, true, null)', null, 116],
        'args/int' => ['bench_args(7, "abc", 0.25, true, 91)', null, 111],
    ];

    foreach ([16, 1024] as $size) {
        $values = range(1, $size);
        $total = intdiv($size * ($size + 1), 2);
        $map = [];
        foreach ($values as $value) {
            $map["key-$value"] = $value;
        }

        $cases["sum/packed/$size"] = ['bench_sum($input)', $values, $total];
        $cases["sum/map/$size"] = ['bench_sum($input)', $map, $total];
        $cases["build/$size"] = ['bench_build($input)', $size, range(0, $size - 1)];
    }

    $holes = $values;
    $holesTotal = $total;
    for ($index = 3; $index < count($values); $index += 4) {
        $holesTotal -= $holes[$index];
        unset($holes[$index]);
    }
    $cases['sum/holes/1024'] = ['bench_sum($input)', $holes, $holesTotal];

    $references = range(1, 256);
    $mixed = [];
    foreach ($references as $index => $value) {
        $mixed[] = $value;
        $mixed[] = (string) $value;
        $mixed[] = (float) $value;
        $mixed[] =& $references[$index];
    }
    // Keep both owners of the referenced integers alive during the sample.
    $cases['sum/mixed/1024'] = ['bench_sum($input[0])', [$mixed, $references], 256 * 257];

    $cases['lookup/hit'] = ['bench_lookup($input[0], $input[1])', [$map, 'key-512'], 512];
    $cases['lookup/miss'] = ['bench_lookup($input[0], $input[1])', [$map, 'missing-key'], null];
    $copy = $values;
    $copy[0] = -1;
    $cases['array/cow'] = ['bench_cow($input, -1)', $values, $copy];

    $point = new BenchPoint();
    $point->value = 42;
    $cases['method'] = ['$input->read()', $point, 42];
    $cases['pipeline'] = ['pipeline($input)', implode(',', array_fill(0, 64, 'field')), 320];

    return $cases;
}

function requireResult(string $name, mixed $actual, mixed $expected): void
{
    if ($actual !== $expected) {
        throw new RuntimeException("$name returned an unexpected result");
    }
}

function verifyCases(array $cases): void
{
    foreach ($cases as $name => [$expression, $input, $expected]) {
        requireResult($name, eval("declare(strict_types=1); return $expression;"), $expected);
    }

    $source = range(1, 1024);
    $copy = bench_cow($source, -1);
    requireResult('original array after copy-on-write', $source, range(1, 1024));
    $source[0] = -2;
    requireResult('copy isolated from later write', $copy[0], -1);

    $failure = new LogicException('benchmark callback failed');
    try {
        bench_invoke(static fn (int $unused) => throw $failure, 0);
        throw new RuntimeException('Benchmark callback did not propagate its exception');
    } catch (LogicException $error) {
        requireResult('callback exception identity', $error, $failure);
    }

    requireResult('empty list', bench_build(0), []);
    requireResult('mixed array with holes', bench_sum([0 => 2, 2 => '3', 3 => -4]), -2);
    $number = 42;
    requireResult('referenced integer', bench_sum([&$number]), 42);
    $point = new BenchPoint();
    $point->value =& $number;
    requireResult('referenced property', $point->read(), 42);

    requireResult('field boundaries', bench_split(",a,\0,"), ['', 'a', "\0", '']);
    requireResult('ASCII uppercase', bench_upper("aZ\0\xff"), "AZ\0\xff");
    requireResult('binary string length', bench_length("a\0b"), 3);

    foreach ([-1, 65_537] as $size) {
        try {
            bench_build($size);
        } catch (ValueError) {
            continue;
        }
        throw new RuntimeException('bench_build accepted a size outside its range');
    }
}
