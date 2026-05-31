--TEST--
testExpectArgArrayObject() — covers .array, .object+class, nullable object+class
--FILE--
<?php

use function MyPHPExt\testExpectArgArrayObject;

// === Success: array + User (covers: .array type match, .object+class instanceof) ===
echo "=== array + User ===", PHP_EOL;
$u1 = new \MyPHPExt\User("Alice", 30);
var_dump(testExpectArgArrayObject(["x" => 1, "y" => 2], $u1));

// === Success: array + User + extra User (covers: nullable+class with User value) ===
echo "=== array + User + nullable User ===", PHP_EOL;
$u2a = new \MyPHPExt\User("First", 10);
$u2b = new \MyPHPExt\User("Second", 20);
var_dump(testExpectArgArrayObject([1, 2, 3], $u2a, $u2b));

// === Success: array + User + null (covers: nullable+class with null -> .null) ===
echo "=== array + User + null ===", PHP_EOL;
$u3 = new \MyPHPExt\User("Bob", 25);
var_dump(testExpectArgArrayObject(["a"], $u3, null));

// === Success: array + User + omitted (covers: optional not passed -> null) ===
echo "=== array + User (no 3rd arg) ===", PHP_EOL;
$u4 = new \MyPHPExt\User("Charlie", 40);
var_dump(testExpectArgArrayObject([], $u4));

// === Error: too few args (covers: required not passed) ===
echo "=== too few: 0 args ===", PHP_EOL;
try { testExpectArgArrayObject(); } catch (ArgumentCountError $e) { echo $e->getMessage(), PHP_EOL; }

echo "=== too few: 1 arg ===", PHP_EOL;
try { testExpectArgArrayObject([]); } catch (ArgumentCountError $e) { echo $e->getMessage(), PHP_EOL; }

// === Error: too many args (covers: count > max) ===
echo "=== too many: 4 args ===", PHP_EOL;
$u = new \MyPHPExt\User("X", 0);
try { testExpectArgArrayObject([], $u, null, "extra"); } catch (ArgumentCountError $e) { echo $e->getMessage(), PHP_EOL; }

// === Error: wrong type for array (covers: .array type mismatch) ===
echo "=== wrong type: string for array ===", PHP_EOL;
try { testExpectArgArrayObject("not_array", $u); } catch (TypeError $e) { echo $e->getMessage(), PHP_EOL; }

// === Error: not an object for user (covers: .object class check fails on non-object) ===
echo "=== not object for user: string ===", PHP_EOL;
try { testExpectArgArrayObject([], "not_user"); } catch (TypeError $e) { echo $e->getMessage(), PHP_EOL; }

// === Error: wrong class for user (covers: .object instanceof fails) ===
echo "=== wrong class for user: stdClass ===", PHP_EOL;
try { testExpectArgArrayObject([], new stdClass()); } catch (TypeError $e) { echo $e->getMessage(), PHP_EOL; }

// === Error: not object for nullable_user (covers: nullable+class fails on non-object) ===
echo "=== not object for nullable_user: int ===", PHP_EOL;
try { testExpectArgArrayObject([], $u, 123); } catch (TypeError $e) { echo $e->getMessage(), PHP_EOL; }

// === Error: wrong class for nullable_user (covers: nullable+class instanceof fails) ===
echo "=== wrong class for nullable_user: stdClass ===", PHP_EOL;
try { testExpectArgArrayObject([], $u, new stdClass()); } catch (TypeError $e) { echo $e->getMessage(), PHP_EOL; }

?>
--EXPECT--
=== array + User ===
AbstractEntity::onLoad: getId() = 9527
array(3) {
  ["data_count"]=>
  int(2)
  ["user_name"]=>
  string(5) "Alice"
  ["nullable_user"]=>
  NULL
}
=== array + User + nullable User ===
AbstractEntity::onLoad: getId() = 9527
AbstractEntity::onLoad: getId() = 9527
array(3) {
  ["data_count"]=>
  int(3)
  ["user_name"]=>
  string(5) "First"
  ["nullable_user"]=>
  string(6) "Second"
}
=== array + User + null ===
AbstractEntity::onLoad: getId() = 9527
array(3) {
  ["data_count"]=>
  int(1)
  ["user_name"]=>
  string(3) "Bob"
  ["nullable_user"]=>
  NULL
}
=== array + User (no 3rd arg) ===
AbstractEntity::onLoad: getId() = 9527
array(3) {
  ["data_count"]=>
  int(0)
  ["user_name"]=>
  string(7) "Charlie"
  ["nullable_user"]=>
  NULL
}
=== too few: 0 args ===
MyPHPExt\testExpectArgArrayObject() expects at least 2 arguments, 0 given
=== too few: 1 arg ===
MyPHPExt\testExpectArgArrayObject() expects at least 2 arguments, 1 given
=== too many: 4 args ===
AbstractEntity::onLoad: getId() = 9527
MyPHPExt\testExpectArgArrayObject() expects at most 3 arguments, 4 given
=== wrong type: string for array ===
MyPHPExt\testExpectArgArrayObject(): Argument #1 ($data) must be of type array, string given
=== not object for user: string ===
MyPHPExt\testExpectArgArrayObject(): Argument #2 ($user) must be instance of MyPHPExt\User, string given
=== wrong class for user: stdClass ===
MyPHPExt\testExpectArgArrayObject(): Argument #2 ($user) must be instance of MyPHPExt\User, stdClass given
=== not object for nullable_user: int ===
MyPHPExt\testExpectArgArrayObject(): Argument #3 ($nullable_user) must be instance of MyPHPExt\User or null, int given
=== wrong class for nullable_user: stdClass ===
MyPHPExt\testExpectArgArrayObject(): Argument #3 ($nullable_user) must be instance of MyPHPExt\User or null, stdClass given
