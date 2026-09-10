--TEST--
Callable tryCall catches fatal errors from discarded result destructors before Zig cleanup
--EXTENSIONS--
my_php_extension
--INI--
display_errors=0
log_errors=0
--FILE--
<?php
use function MyPHPExt\Test\invokeArguments;

class FatalResult {
    public function __destruct() {
        echo "PHP destructor\n";
        trigger_error('destructor fatal', E_USER_ERROR);
    }
}

register_shutdown_function(static function () { echo "PHP shutdown\n"; });
invokeArguments('callable-cleanup', static fn () => new FatalResult, [], null, true);
echo "unexpected PHP continuation\n";
?>
--EXPECT--
PHP destructor
Zig error: ZendBailout
Zig cleanup
PHP shutdown
