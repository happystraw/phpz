--TEST--
map() function
--FILE--
<?php

use function MyPHPExt\map;

echo "=== int array: double each item ===", PHP_EOL;
$nums = [1, 2, 3, 4];
$doubled = map($nums, function (int $n): int {
    return $n * 2;
});
var_dump($doubled);

echo "=== string keys preserved ===", PHP_EOL;
$assoc = ['a' => 1, 'b' => 2, 'c' => 3];
$with_key = map($assoc, function (int $v): string {
    return "val_{$v}";
});
var_dump($with_key);

echo "=== empty array ===", PHP_EOL;
$empty = map([], function ($x) { return $x; });
var_dump($empty);

echo "=== mixed key types ===", PHP_EOL;
$mixed = ['foo', 42 => 'bar', 'baz' => 'qux'];
$upper = map($mixed, 'strtoupper');
var_dump($upper);

echo "=== closure with external variable ===", PHP_EOL;
$factor = 10;
$scaled = map([2, 5, 7], function (int $n) use ($factor): int {
    return $n * $factor;
});
var_dump($scaled);

echo "=== object mapping ===", PHP_EOL;
$objs = [new stdClass(), new stdClass()];
$hashes = map($objs, 'spl_object_hash');
var_dump($hashes);

?>
--EXPECTF--
=== int array: double each item ===
array(4) {
  [0]=>
  int(2)
  [1]=>
  int(4)
  [2]=>
  int(6)
  [3]=>
  int(8)
}
=== string keys preserved ===
array(3) {
  ["a"]=>
  string(5) "val_1"
  ["b"]=>
  string(5) "val_2"
  ["c"]=>
  string(5) "val_3"
}
=== empty array ===
array(0) {
}
=== mixed key types ===
array(3) {
  [0]=>
  string(3) "FOO"
  [42]=>
  string(3) "BAR"
  ["baz"]=>
  string(3) "QUX"
}
=== closure with external variable ===
array(3) {
  [0]=>
  int(20)
  [1]=>
  int(50)
  [2]=>
  int(70)
}
=== object mapping ===
array(2) {
  [0]=>
  string(%d) "%x"
  [1]=>
  string(%d) "%x"
}
