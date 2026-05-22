--TEST--
Context::eval with different value types
--FILE--
<?php

use Pjs\Runtime;
use Pjs\Context;

$rt = new Runtime();
$ctx = new Context($rt);

var_dump($ctx->eval("42"));
var_dump($ctx->eval("'hello'"));
var_dump($ctx->eval("true"));
var_dump($ctx->eval("false"));
var_dump($ctx->eval("null"));
var_dump($ctx->eval("[1, 2, 3]"));

?>
--EXPECTF--
object(Pjs\Value)%A (1) {
  ["value"]=>
  float(42)
}
object(Pjs\Value)%A (1) {
  ["value"]=>
  string(5) "hello"
}
object(Pjs\Value)%A (1) {
  ["value"]=>
  bool(true)
}
object(Pjs\Value)%A (1) {
  ["value"]=>
  bool(false)
}
object(Pjs\Value)%A (1) {
  ["value"]=>
  NULL
}
object(Pjs\Value)%A (1) {
  ["value"]=>
  string(5) "1,2,3"
}
