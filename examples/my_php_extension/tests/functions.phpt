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
array(2) {
  ["first"]=>
  int(4)
  [8]=>
  int(6)
}
string(5) "0.1.0"
