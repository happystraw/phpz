--TEST--
zend.Array.sort keeps the array alive when a comparison releases its last owner
--EXTENSIONS--
my_php_extension
--FILE--
<?php
MyPHPExt\Test\checkArraySort();
echo "done\n";
?>
--EXPECT--
done
