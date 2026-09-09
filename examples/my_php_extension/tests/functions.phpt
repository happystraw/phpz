--TEST--
my_php_extension functions
--EXTENSIONS--
my_php_extension
--FILE--
<?php
hello();
var_dump(greet('Zig'));

$value = 10;
MyPHPExt\increment($value, 5);
var_dump($value);

$alias =& $value;
MyPHPExt\increment($alias);
var_dump($value, $alias);

foreach (['abc', 1.5, [], null, true] as $invalid) {
    $before = $invalid;
    try {
        MyPHPExt\increment($invalid);
    } catch (TypeError $error) {
        echo $error::class, ': ', $error->getMessage(), "\n";
    }
    var_dump($invalid === $before);
}

var_dump(MyPHPExt\mapValues(
    ['first' => 2, 8 => 3],
    static fn (int $value): int => $value * 2,
));
var_dump(MyPHPExt\VERSION);
?>
--EXPECT--
Hello from ZIG!
string(11) "Hello, Zig!"
int(15)
int(16)
int(16)
TypeError: MyPHPExt\increment(): Argument #1 ($value) must be of type int, string given
bool(true)
TypeError: MyPHPExt\increment(): Argument #1 ($value) must be of type int, float given
bool(true)
TypeError: MyPHPExt\increment(): Argument #1 ($value) must be of type int, array given
bool(true)
TypeError: MyPHPExt\increment(): Argument #1 ($value) must be of type int, null given
bool(true)
TypeError: MyPHPExt\increment(): Argument #1 ($value) must be of type int, bool given
bool(true)
array(2) {
  ["first"]=>
  int(4)
  [8]=>
  int(6)
}
string(5) "0.1.0"
