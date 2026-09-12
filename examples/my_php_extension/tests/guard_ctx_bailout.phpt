--TEST--
GuardCtx cleans nested scopes across Ctx handlers before rethrowing Zend bailout
--EXTENSIONS--
my_php_extension
--INI--
display_errors=0
log_errors=0
--FILE--
<?php
use function MyPHPExt\Test\guardResources;
use function MyPHPExt\Test\invokeArguments;

register_shutdown_function(static function () { echo "PHP shutdown\n"; });
guardResources('outer', static function () {
    invokeArguments('callable', static function () {
        guardResources('inner', static function () {
            echo "PHP fatal\n";
            trigger_error('guard fatal', E_USER_ERROR);
        });
        echo "unexpected inner continuation\n";
    }, [], null, false);
    echo "unexpected outer continuation\n";
});
echo "unexpected PHP continuation\n";
?>
--EXPECT--
PHP fatal
cleanup inner 2
cleanup inner 1
cleanup outer 2
cleanup outer 1
PHP shutdown
