--TEST--
Explicit array separation preserves the input when writing a copied zval
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\separateArray;

$source = ['count' => 0];
$copy = $source;
$alias =& $source;
$result = separateArray($alias);
var_dump($result === ['count' => 1, 0 => 2, 1 => 3]);
var_dump($source === ['count' => 0] && $copy === $source && $alias === $source);
var_dump(separateArray([]) === ['count' => 1, 0 => 2, 1 => 3]);
?>
--EXPECT--
bool(true)
bool(true)
bool(true)
