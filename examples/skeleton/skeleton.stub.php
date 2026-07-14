<?php

/**
 * @generate-legacy-arginfo 80200
 * @generate-class-entries
 * @undocumentable
 */

function hello(): void {}

function greet(string $name): string {}

class Counter
{
    public function __construct(int $n = 0) {}

    public function add(int $n): void {}

    public function dec(int $n): void {}

    public function value(): int {}
}
