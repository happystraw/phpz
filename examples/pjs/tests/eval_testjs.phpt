--TEST--
eval: test.js functions
--FILE--
<?php

use Pjs\Runtime;
use Pjs\Context;

$rt = new Runtime();
$ctx = new Context($rt);

$ctx->eval(file_get_contents('tests/test.js'));

echo "greet: ";
var_dump($ctx->eval('greet("World")'));

echo "fibonacci: ";
var_dump($ctx->eval('fibonacci(8)'));

echo "introduce: ";
var_dump($ctx->eval('testResults.person.introduce()'));

?>
--EXPECTF--
greet: object(Pjs\Value)%A (1) {
  ["value"]=>
  string(13) "Hello, World!"
}
fibonacci: object(Pjs\Value)%A (1) {
  ["value"]=>
  float(21)
}
introduce: object(Pjs\Value)%A (1) {
  ["value"]=>
  string(21) "Alice is 25 years old"
}
