--TEST--
eval: new Date
--FILE--
<?php

use Pjs\Runtime;
use Pjs\Context;

$rt = new Runtime();
$ctx = new Context($rt);
var_dump($ctx->eval("new Date"));

?>
--EXPECTF--
object(Pjs\Value)%A (1) {
  ["value"]=>
  string(%d) "%s"
}
