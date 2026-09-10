--TEST--
Callable tryCall reports exit from discarded result destructors and preserves termination
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\invokeArguments;

class ExitingResult {
    public function __destruct() {
        echo "PHP destructor\n";
        exit(7);
    }
}

register_shutdown_function(static function () { echo "PHP shutdown\n"; });
invokeArguments('callable-cleanup', static fn ($value) => new ExitingResult, [10], null, true);
echo "unexpected PHP continuation\n";
?>
--EXPECT--
PHP destructor
Zig error: PhpException
Zig cleanup
PHP shutdown
