<?php

/**
 * @generate-class-entries
 * @undocumentable
 */

/* ========== global namespace ========== */

namespace {
    // gen_stub.php resolves Attribute::TARGET_* constants through the @cvalue
    // metadata declared by PHP's own Attribute stub. Prefer running
    // php-src/build/gen_stub.php; for a copied standalone gen_stub.php, also
    // copy php-src/Zend/zend_attributes.stub.php to ./Zend/zend_attributes.stub.php.
    require "Zend/zend_attributes.stub.php";

    function hello(): void
    {
    }

    function greet(string $name): string
    {
    }

    function iniGetGreeting(): string
    {
    }

    function iniGetMaxUsers(): int
    {
    }

    function iniGetDebug(): bool
    {
    }

    function iniGetMode(): string
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

    function testExpectArgScalars(string $str, int $int, float $float, bool $flag = true, ?string $nullable_str = null, int $opt_int = 0): array
    {
    }

    function testExpectArgArrayObject(array $data, \MyPHPExt\User $user, ?\MyPHPExt\User $nullable_user = null): array
    {
    }

    function testExpectArgMixed(mixed $value): mixed
    {
    }

    function inspectObjectProperty(object $obj, string $name, bool $silent = false): array
    {
    }

    function tryCreateInvalidUser(): void
    {
    }

    function testHeapAllocatorBailout(): array
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

    // This sample uses an OR expression of multiple Attribute::TARGET_* constants.
    // Regenerate arginfo with PHP 8.3+ gen_stub.php; PHP 8.2's generator keeps
    // only the last @cvalue constant in this expression.
    #[\Attribute(\Attribute::TARGET_CLASS | \Attribute::TARGET_PARAMETER | \Attribute::IS_REPEATABLE)]
    final class ExampleAttribute
    {
        public string $name;
        public ?string $note = null;

        public function __construct(string $name, ?string $note = null)
        {
        }
    }

    abstract class AbstractEntity implements Identifiable
    {
        protected function onLoad(): void
        {
        }

        abstract public function handle(string|int $id): void;
    }

    #[ExampleAttribute("entity", "primary user model")]
    #[ExampleAttribute("audited")]
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

        public function handle(#[ExampleAttribute("identifier", "string or int")] string|int $id): void
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
        public function __construct(int $n = 0)
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

    class ArrayLike implements \ArrayAccess, \Countable, \Iterator
    {
        public function __construct(array $data = [])
        {
        }

        public function toArray(): array
        {
        }

        // ArrayAccess
        public function offsetExists(mixed $offset): bool
        {
        }

        public function offsetGet(mixed $offset): mixed
        {
        }

        public function offsetSet(mixed $offset, mixed $value): void
        {
        }

        public function offsetUnset(mixed $offset): void
        {
        }

        // Countable
        public function count(): int
        {
        }

        // Iterator
        public function current(): mixed
        {
        }

        public function key(): mixed
        {
        }

        public function next(): void
        {
        }

        public function rewind(): void
        {
        }

        public function valid(): bool
        {
        }
    }
}
