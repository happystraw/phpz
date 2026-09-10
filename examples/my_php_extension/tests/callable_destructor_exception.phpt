--TEST--
Callable call and tryCall report exceptions from discarded result destructors
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\invokeArguments;

class ThrowingResult {
    public function __destruct() {
        throw new RuntimeException('destructor exception');
    }
}

foreach ([false, true] as $guarded) {
    foreach ([[], [10]] as $positional) {
        echo $guarded ? 'guarded' : 'plain', ' ', count($positional), "\n";
        try {
            invokeArguments('callable-cleanup', static fn ($first = 1, $second = 2) => new ThrowingResult,
                $positional, ['second' => 20], $guarded);
            echo "unexpected PHP continuation\n";
        } catch (RuntimeException $e) {
            echo 'PHP caught: ', $e->getMessage(), "\n";
        }
    }
}
?>
--EXPECT--
plain 0
Zig error: PhpException
Zig cleanup
PHP caught: destructor exception
plain 1
Zig error: PhpException
Zig cleanup
PHP caught: destructor exception
guarded 0
Zig error: PhpException
Zig cleanup
PHP caught: destructor exception
guarded 1
Zig error: PhpException
Zig cleanup
PHP caught: destructor exception
