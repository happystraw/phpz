--TEST--
Object init releases a factory result with a pending exception without invoking its destructor
--EXTENSIONS--
my_php_extension
--FILE--
<?php
class NativeBoundaryTarget {}
MyPHPExt\Test\checkObjectCreation('exception');
echo "Factory cleanup passed\n";
?>
--EXPECT--
Factory cleanup passed
