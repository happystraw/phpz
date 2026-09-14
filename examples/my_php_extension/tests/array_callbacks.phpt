--TEST--
Array callbacks report PHP exceptions and preserve native callback control flow
--EXTENSIONS--
my_php_extension
--FILE--
<?php
MyPHPExt\Test\checkArrayCallbacks();
echo "Array callbacks passed\n";
?>
--EXPECT--
Array callbacks passed
