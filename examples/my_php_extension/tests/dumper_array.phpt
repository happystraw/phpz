--TEST--
Dumper::dump with arrays
--FILE--
<?php

echo "--- list ---\n";
\MyPHPExt\Dumper::dump([1, 2, 3]);

echo "--- assoc ---\n";
\MyPHPExt\Dumper::dump(["a" => 1, "b" => 2]);

echo "--- nested ---\n";
\MyPHPExt\Dumper::dump(["a" => 1, "b" => [2, 3, "x" => [4, 5]], "c" => ["nested" => ["deep" => true, -1 => -1, -3 => new \stdClass]]]);

?>
--EXPECTF--
--- list ---
array(3) {
  [0] =>
  int(1)
  [1] =>
  int(2)
  [2] =>
  int(3)
}
--- assoc ---
array(2) {
  ["a"] =>
  int(1)
  ["b"] =>
  int(2)
}
--- nested ---
array(3) {
  ["a"] =>
  int(1)
  ["b"] =>
  array(3) {
    [0] =>
    int(2)
    [1] =>
    int(3)
    ["x"] =>
    array(2) {
      [0] =>
      int(4)
      [1] =>
      int(5)
    }
  }
  ["c"] =>
  array(1) {
    ["nested"] =>
    array(3) {
      ["deep"] =>
      bool(true)
      [-1] =>
      int(-1)
      [-3] =>
      %Aclass stdClass%A
    }
  }
}
