<?php

/**
 * @generate-class-entries
 * @undocumentable
 */

namespace {
    function hello(): void
    {
    }

    function greet(string $name): string
    {
    }
}

namespace MyPHPExt{
    function human(string $name, int|null $age = NULL): MyPHPExt\Human
    {
    }
    final class Counter
    {
        public function __construct(int $n)
        {
        }

        public function add(int $n): void
        {
        }

        public function dec(int $n): void
        {
        }

        public function value(): int
        {
        }
    }

    final class Human implements \Stringable
    {
        public function __construct(string $name, int|null $age = NULL)
        {
        }

        public function setName(string $name): void
        {
        }

        public function getName(): string
        {
        }

        public function setAge(int|null $age): void
        {
        }

        public function getAge(): int|null
        {
        }

        public function __toString(): string
        {
        }

        public static function species(): string
        {
        }
    }
}
