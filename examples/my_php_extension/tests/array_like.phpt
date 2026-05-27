--TEST--
ArrayLike implements ArrayAccess, Countable, Iterator
--SKIPIF--
<?php
if (!extension_loaded('my_php_extension')) print 'skip';
?>
--FILE--
<?php

// ── construct + toArray ─────────────────────────────────────────

$empty = new MyPHPExt\ArrayLike();
var_dump($empty->toArray());

$data = new MyPHPExt\ArrayLike(['a' => 1, 'b' => 2]);
var_dump($data->toArray());

// ── ArrayAccess: offsetExists / offsetGet ───────────────────────

var_dump(isset($data['a']));       // true
var_dump(isset($data['x']));       // false
var_dump($data['a']);              // 1
var_dump($data['x']);              // null (key not found)

// ── ArrayAccess: offsetSet ──────────────────────────────────────

$data['c'] = 3;
$data['d'] = 'hello';
$data[] = 'append';
var_dump($data->toArray());

// ── ArrayAccess: offsetUnset ────────────────────────────────────

unset($data['d']);
var_dump($data->toArray());
var_dump(isset($data['d']));       // false

// ── Countable: count ────────────────────────────────────────────

var_dump(count($data));

// ── int keys ────────────────────────────────────────────────────

$intKeys = new MyPHPExt\ArrayLike([10 => 'a', 20 => 'b']);
var_dump($intKeys[10]);            // 'a'
var_dump(isset($intKeys[10]));     // true
$intKeys[30] = 'c';
var_dump($intKeys->toArray());

// ── Iterator: foreach ───────────────────────────────────────────

$it = new MyPHPExt\ArrayLike(['x' => 10, 'y' => 20, 'z' => 30]);
$keys = [];
$values = [];
foreach ($it as $k => $v) {
    $keys[] = $k;
    $values[] = $v;
}
var_dump($keys);
var_dump($values);

// ── Iterator: manual iteration ──────────────────────────────────

$manual = new MyPHPExt\ArrayLike(['one' => 1, 'two' => 2]);
$manual->rewind();
var_dump($manual->valid());    // true
var_dump($manual->current());  // 1
var_dump($manual->key());      // 'one'
$manual->next();
var_dump($manual->valid());    // true
var_dump($manual->current());  // 2
var_dump($manual->key());      // 'two'
$manual->next();
var_dump($manual->valid());    // false
var_dump($manual->current());  // null
var_dump($manual->key());      // null

// ── toArray returns independent copy ─────────────────────────────

$original = new MyPHPExt\ArrayLike(['x' => 1]);
$copy = $original->toArray();
$copy['y'] = 2;
var_dump($original->toArray());  // only ['x' => 1], not affected

// ── empty array foreach ──────────────────────────────────────────

$emptyArr = new MyPHPExt\ArrayLike();
$count = 0;
foreach ($emptyArr as $k => $v) {
    $count++;
}
var_dump($count);  // 0

// ── rewind + re-iterate ──────────────────────────────────────────

$twice = new MyPHPExt\ArrayLike(['a' => 1, 'b' => 2]);
$first = [];
foreach ($twice as $k => $v) { $first[] = $v; }
$second = [];
foreach ($twice as $k => $v) { $second[] = $v; }
var_dump($first === $second);  // true

echo "done\n";
?>
--EXPECT--
array(0) {
}
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
array(5) {
  ["a"]=>
  int(1)
  ["b"]=>
  int(2)
  ["c"]=>
  int(3)
  ["d"]=>
  string(5) "hello"
  [0]=>
  string(6) "append"
}
array(4) {
  ["a"]=>
  int(1)
  ["b"]=>
  int(2)
  ["c"]=>
  int(3)
  [0]=>
  string(6) "append"
}
bool(false)
int(4)
string(1) "a"
bool(true)
array(3) {
  [10]=>
  string(1) "a"
  [20]=>
  string(1) "b"
  [30]=>
  string(1) "c"
}
array(3) {
  [0]=>
  string(1) "x"
  [1]=>
  string(1) "y"
  [2]=>
  string(1) "z"
}
array(3) {
  [0]=>
  int(10)
  [1]=>
  int(20)
  [2]=>
  int(30)
}
bool(true)
int(1)
string(3) "one"
bool(true)
int(2)
string(3) "two"
bool(false)
NULL
NULL
array(1) {
  ["x"]=>
  int(1)
}
int(0)
bool(true)
done
