<?php

/**
 * @generate-class-entries
 * @undocumentable
 */

/* ========== global namespace ========== */

namespace {
    function hello(): void
    {
    }

    function greet(string $name): string
    {
    }

    /** @var string */
    const MY_EXT_VERSION = "1.0.0";
}

/* ========== named namespace ========== */

namespace MyPHPExt {
    /** @var int */
    const VERSION = 1;

    function increment(int &$value): void
    {
    }

    function findById(string|int $id): ?User
    {
    }

    function getDefaultUser(): User
    {
    }

    function listStatuses(): array
    {
    }

    function map(array $arr, callable $cb): array
    {
    }

    interface Identifiable
    {
        public function getId(): int;
    }

    enum Status: int
    {
        case Active = 1;
        case Inactive = 0;
    }

    enum Role: string
    {
        case Admin = 'admin';
        case User = 'user';
    }

    class MyError extends \Exception
    {
    }

    abstract class AbstractEntity implements Identifiable
    {
        protected function onLoad(): void
        {
        }

        abstract public function handle(string|int $id): void;
    }

    final class User extends AbstractEntity implements \Stringable
    {
        public string $name;
        public int|null $age = null;
        /** @var int */
        public const MIN_AGE = 0;

        public function __construct(string $name, int|null $age = null)
        {
        }

        public function getId(): int
        {
        }

        public function handle(string|int $id): void
        {
        }

        public function __toString(): string
        {
        }
    }

    class Dumper
    {
        public static function dump(mixed... $value): void
        {
        }
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
}
