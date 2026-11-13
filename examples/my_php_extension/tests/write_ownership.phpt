--TEST--
Array/object writes keep immutable arrays non-refcounted and clean up failed appends
--EXTENSIONS--
my_php_extension
--FILE--
<?php
MyPHPExt\Test\checkWriteOwnership([]);
echo "write ownership passed\n";
?>
--EXPECT--
write ownership passed
