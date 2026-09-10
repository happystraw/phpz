<?php

/**
 * @generate-legacy-arginfo 80200
 * @generate-class-entries
 * @undocumentable
 */

namespace {
    require "Zend/zend_attributes.stub.php";

    function hello(): void {}

    function greet(string $name): string {}
}

namespace MyPHPExt {
    /** @var string */
    const VERSION = "0.1.0";

    function increment(int &$value, int $by = 1): void {}

    function mapValues(array $values, callable $mapper): array {}

    function makeSumClosure(): \Closure {}

    function makeCounter(int $start = 0, mixed $held = null): \Closure {}

    function makeReference(mixed &$value): \Closure {}

    final class ClosureCounter
    {
        private function __construct() {}

        public function __invoke(int $step = 1): int {}
    }

    final class ClosureRef
    {
        private function __construct() {}

        public function &__invoke(): mixed {}
    }

    interface Identifiable
    {
        public function getId(): int;
    }

    enum Status: int
    {
        case Inactive = 0;
        case Active = 1;
    }

    enum Role: string
    {
        case User = "user";
        case Admin = "admin";
    }

    #[\Attribute(\Attribute::TARGET_CLASS | \Attribute::TARGET_PARAMETER | \Attribute::IS_REPEATABLE)]
    final class Tag
    {
        public string $name;
        public ?string $description;

        public function __construct(
            string $name,
            ?string $description = null,
        ) {}
    }

    #[Tag("entity")]
    abstract class Entity implements Identifiable
    {
        protected int $id;

        protected function __construct(int $id) {}

        final public function getId(): int {}

        abstract public function label(): string;
    }

    #[Tag("model", "Demonstrates properties, inheritance, enums, and attributes")]
    class User extends Entity implements \Stringable
    {
        /** @var int */
        public const MIN_AGE = 0;

        public string $name;
        public ?int $age;
        public Role $role;
        public Status $status;

        public function __construct(
            #[Tag("identifier")]
            int $id,
            string $name,
            ?int $age = null,
            Role $role = Role::User,
            Status $status = Status::Active,
        ) {}

        public function label(): string {}

        /** @alias MyPHPExt\User::label */
        public function __toString(): string {}
    }

    class BigInteger
    {
        public function __construct(int|string $value = 0) {}

        public function value(): string {}

        /** @alias MyPHPExt\BigInteger::value */
        public function __toString(): string {}
    }

    final class Counter
    {
        public function __construct(int $value = 0) {}

        public function increment(int $by = 1): int {}

        public function decrement(int $by = 1): int {}

        public function value(): int {}

        public function reset(int $value = 0): void {}
    }

    final class Dumper
    {
        public static function dump(mixed ...$values): void {}
    }

    class Collection implements \ArrayAccess, \Countable, \Iterator
    {
        public function __construct(array $values = []) {}

        public function toArray(): array {}

        public function offsetExists(mixed $offset): bool {}

        public function offsetGet(mixed $offset): mixed {}

        public function offsetSet(mixed $offset, mixed $value): void {}

        public function offsetUnset(mixed $offset): void {}

        public function count(): int {}

        public function current(): mixed {}

        public function key(): mixed {}

        public function next(): void {}

        public function rewind(): void {}

        public function valid(): bool {}
    }

    class Config
    {
        public static function greeting(): string {}

        public static function maxUsers(): int {}

        public static function debugEnabled(): bool {}

        public static function mode(): string {}
    }

    class Metrics
    {
        public static function snapshot(): array {}

        public static function reset(): void {}
    }
}

namespace MyPHPExt\Test {
    function checkedNamedArguments(int $name, int $age = 2, mixed ...$args): array {}

    function collectArguments(int $name = 1, int $age = 2, mixed ...$args): array {}

    function collectReferenceArguments(mixed &...$args): array {}

    function invokeArguments(string $mode, callable $target, array $positional, ?array $named_params, bool $guarded): mixed {}

    function makeHandlerClosure(): \Closure {}

    function makeFnClosure(string $kind = "sum"): \Closure {}

    function wrapClosure(string $name, ?object $object = null, ?string $class = null): \Closure {}

    class SerializableValue
    {
        public function __construct(int $value) {}

        public function value(): int {}

        public function __serialize(): array {}

        public function __unserialize(array $data): void {}
    }

    class GcNode
    {
        public function __construct(mixed $first = null, mixed $second = null, ?callable $callback = null) {}
    }

    function allocatorBailout(): array {}

    function superglobalsSnapshot(): array {}

    function mutateSuperglobals(): void {}

    function referenceArgument(string $mode, string $type, bool $optional, bool $single, mixed &$value = null): string {}
}
