--TEST--
Standard and dispatched properties propagate lazy initializer exceptions
--EXTENSIONS--
my_php_extension
--SKIPIF--
<?php
if (!method_exists(ReflectionClass::class, 'newLazyGhost')) die('skip lazy objects unavailable');
?>
--FILE--
<?php
class LazyPropertyTarget { public int $value; }
$object = (new ReflectionClass(LazyPropertyTarget::class))->newLazyGhost(function () {
    throw new RuntimeException('initializer failed');
});
MyPHPExt\Test\checkObjectPropertyHandlers($object);
echo "Lazy property checks passed\n";
?>
--EXPECT--
Lazy property checks passed
