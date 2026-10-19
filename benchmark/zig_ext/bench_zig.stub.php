<?php

/**
 * @generate-class-entries
 * @undocumentable
 */

function bench_zig_empty(): void {}

function bench_zig_parse_multi(int $n, string $s, float $d, bool $b, array $arr, object $obj, mixed $v, ?int $opt = null): void {}

function bench_zig_parse_multi_pp(int $n, string $s, float $d, bool $b, array $arr, object $obj, mixed $v, ?int $opt = null): void {}

function bench_zig_array_sum_fast(array $arr): int {}

function bench_zig_array_sum_parse(array $arr): int {}

function bench_zig_add(int $a, int $b): int {}

function bench_zig_muladd(float $a, float $b, float $c): float {}

function bench_zig_str_len(string $s): int {}

function bench_zig_int_to_string(int $n): string {}

function bench_zig_str_upper(string $s): string {}

function bench_zig_array_sum_assoc(array $arr): int {}

function bench_zig_array_build(int $n): array {}

function bench_zig_hash_lookup(array $arr, string $key): mixed {}

function bench_zig_array_identity(array $arr): array {}

function bench_zig_throw(int $code): void {}

function bench_zig_split(string $s, string $separator): array {}

function bench_zig_counter(): int {}

function bench_zig_invoke(callable $callback, mixed $arg): mixed {}

final class BenchZigPoint
{
    public function __construct(float $x, float $y) {}

    public function length(): float {}

    public function translate(float $dx, float $dy): void {}
}
