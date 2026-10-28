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
    function checkStreams(): void {}
    /** @param resource $stream */
    function checkSocketOptions($stream): void {}
    /** @return resource */
    function openStream(string $path) {}
    /** @return resource */
    function openPersistentStream(string $path) {}
    function checkPersistentStreams(string $path): void {}
    /** @return resource */
    function openStreamDir(string $path) {}
    /** @param resource $resource */
    function readStreamDir($resource): ?string {}
    /** @param resource $resource */
    function rewindStreamDir($resource): void {}
    /** @param resource $resource */
    function readStream($resource, int $len): string {}
    function nullableStream(mixed $resource): string {}
    function optionalStream(mixed $resource = null): string {}
    function optionalNullableStream(mixed $resource = null): string {}
    /** @param resource $resource */
    function closeStream($resource): int {}
    /** @param resource $resource */
    function syncStream($resource): void {}
    /**
     * @param resource $source
     * @param resource $destination
     */
    function checkStreamFailures($source, $destination): void {}
    function typedArgument(string $mode, bool $single, mixed $value): mixed {}
    function optionalTypedArgument(string $mode, bool $single, mixed $value = null): mixed {}
    function checkArgumentDeclaration(string $mode, mixed $value = null): bool {}
    function checkStringArguments(string $value): bool {}
    function checkZvalStrings(string $value, object $fixture): string {}
    function checkStringWriteFailure(object $fixture, string $api, string $exception): void {}
    function checkZendStrings(): void {}
    function checkNativeTsrmThreads(): bool {}
    function objectView(object $object, string $purpose): ?array {}
    function readObjectNative(object $object, string $name, string $api): mixed {}
    function writeObjectNative(object $object, string $name, mixed $input, string $api): void {}
    function objectDimension(object $object, string $action, mixed $offset, mixed $input): mixed {}
    function checkObjectViews(array $empty): void {}
    function checkArrayCallbacks(): void {}
    function readLastError(bool $clear_exception): ?array {}
    function checkExceptionBoundary(string $api, mixed $value): void {}
    function checkArrayHashTable(array $references): void {}
    function isArrayList(array $source): bool {}
    function arrayToList(array $source): array {}
    function iterateArray(array $values): array {}
    function lookupKey(array $values, string $key, bool $symtable): mixed {}
    function storeKey(array $values, string $key, mixed $value): array {}
    function deleteKey(array $values, string $key): array {}
    function iterateWhileMutating(): array {}
    function buildList(int $count, int $capacity, mixed $value): array {}
    function checkObjectPropertyHandlers(?object $lazy = null): void {}
    function checkObjectCreation(string $stage): void {}
    function separateArray(array $values): array {}
    function compareArrays(array $left, array $right, bool $ordered, bool $strict): int {}
    function copyArray(array $target, array $source): array {}
    function mergeArray(array $target, array $source, bool $overwrite): array {}
    function constructObject(string $class, array $args, bool $guarded): object {}
    function initObject(string $class): object {}
    function cloneObject(object $object): object {}
    function objectProperties(object $object, bool $standard): array {}
    function hasObjectProperty(object $object, string $name, bool $standard): bool {}
    function lookupClass(string $name, bool $autoload): ?string {}
    function readStaticProperty(string $class, string $name, bool $silent): mixed {}
    function checkConstantMetadata(): void {}
    function readConstant(string $name, bool $silent): mixed {}
    function readClassConstant(string $class, string $name, bool $silent): mixed {}
    function setMixedProperty(object $target, string $name, mixed $value, string $api): void {}
    function setMixedReferenceProperty(object $target, string $name, mixed &$value, string $api): void {}
    function newObject(bool $bare, array $positional, ?array $named_params, bool $guarded): object {}

    class NewValue
    {
        public function __construct(int $first, int $second = 7, bool $fail = false) {}

        public function values(): array {}

        public function __destruct() {}
    }

    class NewBare {}

    class FallibleValue
    {
        public function value(): int {}
    }

    function failNextFallible(string $stage): void {}

    function castValue(mixed $value, string $type, bool $convert): mixed {}

    function castReferenceValue(mixed &$value, string $type, bool $convert): mixed {}

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

        public function invokeCallback(mixed $value, bool $guarded = false): mixed {}
    }

    function allocatorBailout(): void {}

    function allocatorAlignment(): bool {}

    function nativeOutOfMemory(): void {}

    function guardResources(string $label, callable $callback, bool $fail = false): void {}

    function superglobalsSnapshot(): array {}

    function mutateSuperglobals(): void {}

    function referenceArgument(string $mode, string $type, bool $single, mixed &$value): string {}
    function &createReference(string $type, mixed $value): mixed {}
    function &makeReference(mixed $value): mixed {}
    function setReference(mixed &$target, string $type, mixed $value): void {}
    function setReferenceSelf(mixed &$target): void {}
    function &createReferenceCopy(mixed &$source): mixed {}
    function optionalReferenceArgument(string $mode, string $type, bool $single, mixed &$value = null): string {}

    /** @return resource */
    function createResource(int $number, bool $other): mixed {}
    /** @param resource $resource */
    function readResource($resource, bool $other): int {}
    /** @param resource $resource */
    function closeResource($resource): void {}
    /** @param resource $resource */
    function resourceTypeName($resource): ?string {}
    function checkResourceRelease(): bool {}
    function resourceDestructions(): int {}
}
