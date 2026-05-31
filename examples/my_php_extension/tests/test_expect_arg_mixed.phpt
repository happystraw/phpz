--TEST--
testExpectArgMixed() — covers .mixed (returns raw zval)
--FILE--
<?php

use function MyPHPExt\testExpectArgMixed;

// === Success: string value (covers: .mixed returns zv directly) ===
echo "=== string ===", PHP_EOL;
var_dump(testExpectArgMixed("hello world"));

// === Success: int value ===
echo "=== int ===", PHP_EOL;
var_dump(testExpectArgMixed(42));

// === Success: float value ===
echo "=== float ===", PHP_EOL;
var_dump(testExpectArgMixed(3.14));

// === Success: bool true ===
echo "=== bool true ===", PHP_EOL;
var_dump(testExpectArgMixed(true));

// === Success: bool false ===
echo "=== bool false ===", PHP_EOL;
var_dump(testExpectArgMixed(false));

// === Success: null ===
echo "=== null ===", PHP_EOL;
var_dump(testExpectArgMixed(null));

// === Success: array ===
echo "=== array ===", PHP_EOL;
var_dump(testExpectArgMixed([1, "two", 3.0]));

// === Error: too few args ===
echo "=== too few: 0 args ===", PHP_EOL;
try { testExpectArgMixed(); } catch (ArgumentCountError $e) { echo $e->getMessage(), PHP_EOL; }

// === Error: too many args ===
echo "=== too many: 2 args ===", PHP_EOL;
try { testExpectArgMixed(1, 2); } catch (ArgumentCountError $e) { echo $e->getMessage(), PHP_EOL; }

?>
--EXPECT--
=== string ===
string(11) "hello world"
=== int ===
int(42)
=== float ===
float(3.14)
=== bool true ===
bool(true)
=== bool false ===
bool(false)
=== null ===
NULL
=== array ===
array(3) {
  [0]=>
  int(1)
  [1]=>
  string(3) "two"
  [2]=>
  float(3)
}
=== too few: 0 args ===
MyPHPExt\testExpectArgMixed() expects exactly 1 argument, 0 given
=== too many: 2 args ===
MyPHPExt\testExpectArgMixed() expects exactly 1 argument, 2 given
