--TEST--
Direct internal method reference returns support temporary values and explicit aliases
--EXTENSIONS--
my_php_extension
--FILE--
<?php
$value = 20;
$reference = MyPHPExt\makeReference($value);
$owner = (new ReflectionFunction($reference))->getClosureThis();
var_dump($owner->__invoke() + 22);
$copy = $owner->__invoke();
$alias =& $owner->__invoke();
$alias = 30;
var_dump($copy, $value);
$value = ['key' => 42];
var_dump($owner->__invoke()['key']);
?>
--EXPECT--
int(42)
int(20)
int(30)
int(42)
