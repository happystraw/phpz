--TEST--
zval.Array.set stores sliced "" and "-" keys as strings and keeps numeric keys as integers
--EXTENSIONS--
my_php_extension
--FILE--
<?php
var_dump(MyPHPExt\Test\setSlicedKeys());
?>
--EXPECT--
array(3) {
  ["-"]=>
  int(1)
  [""]=>
  string(5) "empty"
  [7]=>
  bool(true)
}
