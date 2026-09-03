--TEST--
MyPHPExt\Collection implements ArrayAccess, Countable, and Iterator
--FILE--
<?php

$collection = new MyPHPExt\Collection(["a" => 1, "b" => 2]);
var_dump($collection->toArray());
var_dump(isset($collection["a"]), isset($collection["missing"]));
var_dump($collection["a"], $collection["missing"]);

$collection["c"] = 3;
$collection[] = 4;
unset($collection["b"]);
var_dump($collection->toArray());
var_dump(count($collection));

$keys = [];
$values = [];
foreach ($collection as $key => $value) {
    $keys[] = $key;
    $values[] = $value;
}
var_dump($keys, $values);

$copy = $collection->toArray();
$copy["local"] = true;
var_dump(isset($collection["local"]));

$clone = clone $collection;
$clone["a"] = 99;
var_dump($collection["a"], $clone["a"]);

?>
--EXPECT--
array(2) {
  ["a"]=>
  int(1)
  ["b"]=>
  int(2)
}
bool(true)
bool(false)
int(1)
NULL
array(3) {
  ["a"]=>
  int(1)
  ["c"]=>
  int(3)
  [0]=>
  int(4)
}
int(3)
array(3) {
  [0]=>
  string(1) "a"
  [1]=>
  string(1) "c"
  [2]=>
  int(0)
}
array(3) {
  [0]=>
  int(1)
  [1]=>
  int(3)
  [2]=>
  int(4)
}
bool(false)
int(1)
int(99)
