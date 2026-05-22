--TEST--
eval: 1+1
--FILE--
<?php

use Pjs\Runtime;
use Pjs\Context;

$rt = new Runtime();
$ctx = new Context($rt);
var_dump($ctx->eval("1+1"));

?>
--EXPECTF--
object(Pjs\Value)%A (1) {
  ["value"]=>
  float(2)
}
