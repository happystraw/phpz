<?php

/**
 * @generate-class-entries
 * @undocumentable
 */

function bench_cpp_empty(): void {}

function bench_cpp_parse_multi(int $n, string $s, float $d, bool $b, array $arr, object $obj, mixed $v, ?int $opt = null): void {}

function bench_cpp_parse_multi_pp(int $n, string $s, float $d, bool $b, array $arr, object $obj, mixed $v, ?int $opt = null): void {}

function bench_cpp_array_sum_fast(array $arr): int {}

function bench_cpp_array_sum_parse(array $arr): int {}

function bench_cpp_add(int $a, int $b): int {}

function bench_cpp_muladd(float $a, float $b, float $c): float {}

function bench_cpp_str_len(string $s): int {}

function bench_cpp_int_to_string(int $n): string {}

function bench_cpp_str_upper(string $s): string {}

function bench_cpp_array_sum_assoc(array $arr): int {}

function bench_cpp_array_build(int $n): array {}

function bench_cpp_hash_lookup(array $arr, string $key): mixed {}

function bench_cpp_array_identity(array $arr): array {}

function bench_cpp_throw(int $code): void {}

function bench_cpp_split(string $s, string $separator): array {}

function bench_cpp_counter(): int {}

function bench_cpp_invoke(callable $callback, mixed $arg): mixed {}

final class BenchCppPoint
{
    public function __construct(float $x, float $y) {}

    public function length(): float {}

    public function translate(float $dx, float $dy): void {}
}
