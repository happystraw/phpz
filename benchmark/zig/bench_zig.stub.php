<?php

/** @generate-class-entries */

function bench_call(): void {}
function bench_args(int $number, string $text, float $decimal, bool $flag, ?int $optional = null): int {}
function bench_sum(array $values): int {}
function bench_build(int $size): array {}
function bench_invoke(callable $callback, int $value): mixed {}
function bench_lookup(array $values, string $key): ?int {}
function bench_cow(array $values, int $replacement): array {}
function bench_split(string $record): array {}
function bench_upper(string $text): string {}
function bench_length(string $text): int {}

final class BenchPoint
{
    public int $value = 0;

    public function read(): int {}
}
