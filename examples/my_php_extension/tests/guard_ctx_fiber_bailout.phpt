--TEST--
GuardCtx cleans the fatal Fiber and releases a suspended Fiber at request shutdown
--EXTENSIONS--
my_php_extension
--INI--
display_errors=0
log_errors=0
--FILE--
<?php
use function MyPHPExt\Test\guardResources;

register_shutdown_function(static function () { echo "PHP shutdown\n"; });
$a = new Fiber(static function () {
    guardResources('A', static function () {
        echo "A suspended\n";
        Fiber::suspend();
        echo "unexpected A continuation\n";
    });
});
$b = new Fiber(static function () {
    guardResources('B', static function () {
        echo "B fatal\n";
        trigger_error('fiber fatal', E_USER_ERROR);
    });
    echo "unexpected B continuation\n";
});

$a->start();
$b->start();
echo "unexpected PHP continuation\n";
?>
--EXPECT--
A suspended
B fatal
cleanup B 2
cleanup B 1
PHP shutdown
cleanup A 2
cleanup A 1
