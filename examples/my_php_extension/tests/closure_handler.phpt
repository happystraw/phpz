--TEST--
Raw zif_handler closures preserve their handler across cloning and validate arguments
--EXTENSIONS--
my_php_extension
--FILE--
<?php
$closure = MyPHPExt\Test\makeHandlerClosure();
var_dump($closure instanceof Closure, $closure(20, 22));
$copy = clone $closure;
unset($closure);
gc_collect_cycles();
var_dump($copy(-10, 3));
$reflection = new ReflectionFunction($copy);
var_dump($reflection->isInternal(), $reflection->getNumberOfRequiredParameters());
var_dump($reflection->getParameters()[0]->isVariadic());
var_dump($reflection->getParameters()[0]->isPassedByReference());
var_dump($reflection->getReturnType(), $reflection->getClosureThis());
foreach ([[1], [1, 'invalid'], [1, 2, 3]] as $args) {
    try {
        $copy(...$args);
        echo "unexpected success\n";
    } catch (ArgumentCountError|TypeError $error) {
        echo get_class($error), "\n";
    }
}
var_dump($copy(1, 2));
?>
--EXPECT--
bool(true)
int(42)
int(-7)
bool(true)
int(0)
bool(true)
bool(false)
NULL
NULL
ArgumentCountError
TypeError
ArgumentCountError
int(3)
