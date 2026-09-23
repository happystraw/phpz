--TEST--
GuardCtx keeps a suspended Fiber scope separate from another Fiber
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\guardResources;

$a = new Fiber(static function () {
    guardResources('A', static function () {
        echo "A suspended\n";
        Fiber::suspend();
        echo "A resumed\n";
    });
    echo "A returned\n";
});
$b = new Fiber(static function () {
    guardResources('B', static function () { echo "B callback\n"; });
    echo "B returned\n";
});

$a->start();
echo "main after A\n";
$b->start();
echo "main after B\n";
$a->resume();
?>
--EXPECT--
A suspended
main after A
B callback
defer B
cleanup B 2
cleanup B 1
B returned
main after B
A resumed
defer A
cleanup A 2
cleanup A 1
A returned
