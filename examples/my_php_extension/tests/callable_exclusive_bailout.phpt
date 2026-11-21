--TEST--
Callable tryCallAssumeExclusive clears FCI after a discarded-result destructor bails out
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
invokeArguments('callable-exclusive-cleanup', static function ($first, $second) {
    echo "PHP callback: $first, $second\n";
    return new FatalResult();
}, [10], ['second' => 20], true);
echo "unexpected PHP continuation\n";
?>
--EXPECT--
PHP callback: 10, 20
PHP destructor
Zig error: ZendBailout
Zig cleanup
PHP shutdown
