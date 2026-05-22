--TEST--
Dumper::dump with reference
--FILE--
<?php

$a = 42;
$b = &$a;
\MyPHPExt\Dumper::dump($b);

$arr = [1, 2, 3];
$ref = &$arr[0];
\MyPHPExt\Dumper::dump($arr);

?>
--EXPECTF--
int(42)
array(3) {
  [0] =>
  &int(1)
  [1] =>
  int(2)
  [2] =>
  int(3)
}
