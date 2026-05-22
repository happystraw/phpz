--TEST--
Counter class methods
--FILE--
<?php

use MyPHPExt\Counter;

$obj = new Counter(10);
$obj->add(10);
$obj->dec(5);
echo 'counter: ', $obj->value(), PHP_EOL;

?>
--EXPECT--
counter: 15
