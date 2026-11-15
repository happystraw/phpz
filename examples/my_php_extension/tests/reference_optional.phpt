--TEST--
Typed optional by-reference parameters accept a reference or omission
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\markOptionalReference;

$value = 1;
var_dump(markOptionalReference($value), $value);
var_dump(markOptionalReference());

// Passing by reference creates the missing element.
$array = [];
var_dump(markOptionalReference($array['new']), $array);
?>
--EXPECT--
bool(true)
string(6) "marked"
bool(false)
bool(true)
array(1) {
  ["new"]=>
  string(6) "marked"
}
