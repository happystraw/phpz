--TEST--
Object property handlers distinguish null from exceptions and return borrowed tables
--EXTENSIONS--
my_php_extension
--FILE--
<?php
MyPHPExt\Test\checkObjectPropertyHandlers();
echo "Property handlers passed\n";
?>
--EXPECT--
Property handlers passed
