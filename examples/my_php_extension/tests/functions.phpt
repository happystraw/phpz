--TEST--
Functions
--FILE--
<?php

hello();
echo greet('Alice'), PHP_EOL;

echo 'increment(41): ';
$n = 41;
\MyPHPExt\increment($n);
echo $n, PHP_EOL;

echo 'findById:', PHP_EOL;
var_dump(\MyPHPExt\findById(1));
var_dump(\MyPHPExt\findById("abc"));

echo 'getDefaultUser: ';
echo \MyPHPExt\getDefaultUser(), PHP_EOL;

echo 'listStatuses: ';
var_dump(\MyPHPExt\listStatuses());

?>
--EXPECT--
Hello from ZIG!
Hello, Alice!
increment(41): 42
findById:
Found user with ID 1: NULL
Found user with name abc: NULL
getDefaultUser: AbstractEntity::onLoad: getId() = 9527
User(Default)
listStatuses: array(2) {
  ["Active"]=>
  int(1)
  ["Inactive"]=>
  int(0)
}
