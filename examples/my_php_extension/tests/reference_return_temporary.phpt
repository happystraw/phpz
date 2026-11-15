--TEST--
Internal reference returns behave as values in temporary expressions and preserve explicit aliases
--EXTENSIONS--
my_php_extension
--FILE--
<?php
$value = 20;
$reference = MyPHPExt\makeReference($value);
var_dump($reference() + 22);
var_dump($reference() === 20, "value=" . $reference());
$copy = $reference();
$alias =& $reference();
$alias = 30;
var_dump($copy, $value, $reference() + 12);
$value = ['key' => 42];
var_dump($reference()['key']);
foreach ($reference() as $item) var_dump($item);
$copy = $reference();
$alias['key'] = 43;
var_dump($copy['key'], $value['key']);
unset($reference, $alias);
gc_collect_cycles();
var_dump($value);
?>
--EXPECT--
int(42)
bool(true)
string(8) "value=20"
int(20)
int(30)
int(42)
int(42)
int(42)
int(42)
int(43)
array(1) {
  ["key"]=>
  int(43)
}
