<?php

/**
 * @generate-class-entries
 * @undocumentable
 */

function bench_c_empty(): void {}

function bench_c_parse_multi(int $n, string $s, float $d, bool $b, array $arr, object $obj, mixed $v, ?int $opt = null): void {}

function bench_c_parse_multi_pp(int $n, string $s, float $d, bool $b, array $arr, object $obj, mixed $v, ?int $opt = null): void {}

function bench_c_array_sum_fast(array $arr): int {}

function bench_c_array_sum_parse(array $arr): int {}

function bench_c_add(int $a, int $b): int {}

function bench_c_muladd(float $a, float $b, float $c): float {}

function bench_c_str_len(string $s): int {}

function bench_c_int_to_string(int $n): string {}

function bench_c_str_upper(string $s): string {}

function bench_c_array_sum_assoc(array $arr): int {}

function bench_c_array_build(int $n): array {}

function bench_c_hash_lookup(array $arr, string $key): mixed {}

function bench_c_array_identity(array $arr): array {}

function bench_c_throw(int $code): void {}

function bench_c_split(string $s, string $separator): array {}

function bench_c_counter(): int {}

function bench_c_invoke(callable $callback, mixed $arg): mixed {}

final class BenchCPoint
{
    public function __construct(float $x, float $y) {}

    public function length(): float {}

    public function translate(float $dx, float $dy): void {}
}
