--TEST--
Owned callable cache catches bailout from discarded result destruction
--EXTENSIONS--
my_php_extension
--INI--
display_errors=0
log_errors=0
--FILE--
<?php
use function MyPHPExt\Test\invokeArguments;
class FatalCacheResult {
    public function __destruct() {
        echo "PHP destructor\n";
        trigger_error('cache destructor fatal', E_USER_ERROR);
    }
}
register_shutdown_function(static function () { echo "PHP shutdown\n"; });
invokeArguments('cache-cleanup', static fn() => new FatalCacheResult, [], null, true);
echo "unexpected PHP continuation\n";
?>
--EXPECT--
PHP destructor
Zig error: ZendBailout
Zig cleanup
PHP shutdown
