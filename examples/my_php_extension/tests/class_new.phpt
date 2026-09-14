--TEST--
Class new and tryNew construct objects, resolve named arguments and clean up failures
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use MyPHPExt\Test\NewBare;
use MyPHPExt\Test\NewValue;
use function MyPHPExt\Test\newObject;

function check($actual, $expected): void {
    if ($actual !== $expected) {
        throw new Exception(var_export([$actual, $expected], true));
    }
}

function expectError(callable $call, string $type, string $message): void {
    try {
        $call();
    } catch (Throwable $error) {
        check(get_class($error), $type);
        check(str_contains($error->getMessage(), $message), true);
        return;
    }
    throw new Exception('construction unexpectedly succeeded');
}

foreach ([false, true] as $guarded) {
    echo $guarded ? "tryNew\n" : "new\n";
    foreach ([
        [[3], null, [3, 7]],
        [[3, 4], null, [3, 4]],
        [[3], [], [3, 7]],
        [[], ['first' => 3], [3, 7]],
        [[], ['second' => 4, 'first' => 3], [3, 4]],
        [[3], ['second' => 4], [3, 4]],
        [[], [3, 4], [3, 4]],
        [[], [3, 'second' => 4], [3, 4]],
        [[3], [4], [3, 4]],
    ] as [$positional, $named, $expected]) {
        $saved = [$positional, $named];
        $value = newObject(false, $positional, $named, $guarded);
        check($value instanceof NewValue, true);
        check($value->values(), $expected);
        // The wrapper must retain neither the result nor borrowed argument arrays.
        check([$positional, $named], $saved);
        $weak = WeakReference::create($value);
        unset($value);
        check($weak->get(), null);
    }
    echo "arguments and result ownership: passed\n";

    foreach ([
        [[], null, ArgumentCountError::class, 'expects at least 1 argument'],
        [[], ['second' => 4], ArgumentCountError::class, 'not passed'],
        [[], ['unknown' => 4], Error::class, 'Unknown named parameter $unknown'],
        [[3], ['first' => 4], Error::class, 'overwrites previous argument'],
        [[], ['first' => 3, 4], Error::class, 'Cannot use positional argument after named argument'],
        [[], ['first' => []], TypeError::class, 'must be of type int'],
    ] as [$positional, $named, $type, $message]) {
        expectError(fn () => newObject(false, $positional, $named, $guarded), $type, $message);
    }
    echo "argument errors: passed\n";

    // Without a constructor, phpz ignores all arguments, including named ones.
    foreach ([
        [[], null],
        [[], []],
        [[3], null],
        [[], [3]],
        [[3], [4]],
        [[], ['unknown' => 4]],
        [[], [3, 'unknown' => 4]],
        [[3], ['unknown' => 4]],
        [[], ['unknown' => 4, 3]],
    ] as [$positional, $named]) {
        $value = newObject(true, $positional, $named, $guarded);
        check($value instanceof NewBare, true);
        $weak = WeakReference::create($value);
        unset($value);
        check($weak->get(), null);
    }
    echo "without constructor: passed\n";

    // Failure must release the initialized backing without calling __destruct.
    expectError(fn () => newObject(false, [3], ['fail' => true], $guarded), Error::class, 'constructor failed');
    echo "constructor exception preserved: passed\n";
}
?>
--EXPECT--
new
arguments and result ownership: passed
argument errors: passed
without constructor: passed
backing cleanup
constructor exception preserved: passed
tryNew
arguments and result ownership: passed
argument errors: passed
without constructor: passed
backing cleanup
constructor exception preserved: passed
