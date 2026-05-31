--TEST--
testExpectArgScalars() — covers .string, .int, .float, .bool with optional, nullable, zval
--FILE--
<?php

use function MyPHPExt\testExpectArgScalars;

// === Success: all 6 args (covers: required, optional passed, nullable with value, zval) ===
echo "=== all 6 args ===", PHP_EOL;
var_dump(testExpectArgScalars("hello", 42, 3.14, true, "nullable_val", 99));

// === Success: min 3 args (covers: optional not passed -> null, default values) ===
echo "=== min 3 args ===", PHP_EOL;
var_dump(testExpectArgScalars("min", 1, 2.5));

// === Success: null nullable_str (covers: nullable with null -> .null) ===
echo "=== null nullable_str ===", PHP_EOL;
var_dump(testExpectArgScalars("x", 0, 0.0, false, null));

// === Success: 4 args (covers: flag false, nullable_str not passed, opt_int not passed) ===
echo "=== 4 args: name, int, float, flag=false ===", PHP_EOL;
var_dump(testExpectArgScalars("four", 100, 1.23, false));

// === Success: 5 args (covers: flag default=true overriding) ===
echo "=== 5 args ===", PHP_EOL;
var_dump(testExpectArgScalars("five", 200, 5.67, false, "five_nullable"));

// === Error: too few args (covers: required not passed -> ArgumentCountError) ===
echo "=== too few: 0 args ===", PHP_EOL;
try { testExpectArgScalars(); } catch (ArgumentCountError $e) { echo $e->getMessage(), PHP_EOL; }

echo "=== too few: 1 arg ===", PHP_EOL;
try { testExpectArgScalars("a"); } catch (ArgumentCountError $e) { echo $e->getMessage(), PHP_EOL; }

echo "=== too few: 2 args ===", PHP_EOL;
try { testExpectArgScalars("a", 1); } catch (ArgumentCountError $e) { echo $e->getMessage(), PHP_EOL; }

// === Error: too many args (covers: count > max -> ArgumentCountError) ===
echo "=== too many: 7 args ===", PHP_EOL;
try { testExpectArgScalars("a", 1, 2.0, true, "s", 3, "extra"); } catch (ArgumentCountError $e) { echo $e->getMessage(), PHP_EOL; }

// === Error: wrong type for each required arg (covers: type mismatch -> TypeError) ===
echo "=== wrong type: int for str ===", PHP_EOL;
try { testExpectArgScalars(123, 1, 2.0); } catch (TypeError $e) { echo $e->getMessage(), PHP_EOL; }

echo "=== wrong type: string for int ===", PHP_EOL;
try { testExpectArgScalars("a", "bad", 2.0); } catch (TypeError $e) { echo $e->getMessage(), PHP_EOL; }

echo "=== wrong type: string for float ===", PHP_EOL;
try { testExpectArgScalars("a", 1, "bad"); } catch (TypeError $e) { echo $e->getMessage(), PHP_EOL; }

// === Error: wrong type for optional args (covers: nullable type mismatch) ===
echo "=== wrong type: int for bool flag ===", PHP_EOL;
try { testExpectArgScalars("a", 1, 2.0, 123); } catch (TypeError $e) { echo $e->getMessage(), PHP_EOL; }

echo "=== wrong type: int for nullable_str ===", PHP_EOL;
try { testExpectArgScalars("a", 1, 2.0, true, 123); } catch (TypeError $e) { echo $e->getMessage(), PHP_EOL; }

echo "=== wrong type: string for opt_int ===", PHP_EOL;
try { testExpectArgScalars("a", 1, 2.0, true, null, "bad"); } catch (TypeError $e) { echo $e->getMessage(), PHP_EOL; }

?>
--EXPECT--
=== all 6 args ===
array(6) {
  ["str"]=>
  string(5) "hello"
  ["int"]=>
  int(42)
  ["float"]=>
  float(3.14)
  ["flag"]=>
  bool(true)
  ["nullable_str"]=>
  string(12) "nullable_val"
  ["opt_int"]=>
  int(99)
}
=== min 3 args ===
array(6) {
  ["str"]=>
  string(3) "min"
  ["int"]=>
  int(1)
  ["float"]=>
  float(2.5)
  ["flag"]=>
  bool(true)
  ["nullable_str"]=>
  NULL
  ["opt_int"]=>
  int(0)
}
=== null nullable_str ===
array(6) {
  ["str"]=>
  string(1) "x"
  ["int"]=>
  int(0)
  ["float"]=>
  float(0)
  ["flag"]=>
  bool(false)
  ["nullable_str"]=>
  NULL
  ["opt_int"]=>
  int(0)
}
=== 4 args: name, int, float, flag=false ===
array(6) {
  ["str"]=>
  string(4) "four"
  ["int"]=>
  int(100)
  ["float"]=>
  float(1.23)
  ["flag"]=>
  bool(false)
  ["nullable_str"]=>
  NULL
  ["opt_int"]=>
  int(0)
}
=== 5 args ===
array(6) {
  ["str"]=>
  string(4) "five"
  ["int"]=>
  int(200)
  ["float"]=>
  float(5.67)
  ["flag"]=>
  bool(false)
  ["nullable_str"]=>
  string(13) "five_nullable"
  ["opt_int"]=>
  int(0)
}
=== too few: 0 args ===
MyPHPExt\testExpectArgScalars() expects at least 3 arguments, 0 given
=== too few: 1 arg ===
MyPHPExt\testExpectArgScalars() expects at least 3 arguments, 1 given
=== too few: 2 args ===
MyPHPExt\testExpectArgScalars() expects at least 3 arguments, 2 given
=== too many: 7 args ===
MyPHPExt\testExpectArgScalars() expects at most 6 arguments, 7 given
=== wrong type: int for str ===
MyPHPExt\testExpectArgScalars(): Argument #1 ($str) must be of type string, int given
=== wrong type: string for int ===
MyPHPExt\testExpectArgScalars(): Argument #2 ($int) must be of type int, string given
=== wrong type: string for float ===
MyPHPExt\testExpectArgScalars(): Argument #3 ($float) must be of type float, string given
=== wrong type: int for bool flag ===
MyPHPExt\testExpectArgScalars(): Argument #4 ($flag) must be of type bool, int given
=== wrong type: int for nullable_str ===
MyPHPExt\testExpectArgScalars(): Argument #5 ($nullable_str) must be of type string or null, int given
=== wrong type: string for opt_int ===
MyPHPExt\testExpectArgScalars(): Argument #6 ($opt_int) must be of type int, string given
