<?php

/**
 * @generate-class-entries
 * @undocumentable
 */

namespace {
    function hello_world(): void
    {
    }

    function whoami(string $name, int|string|null $age = NULL): string
    {
    }

}

namespace MyPHPExt{
    final class Human implements \Stringable
    {
        public function __construct(string $name, int|null $age)
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

        public static function version(): void
        {
        }
    }
}
