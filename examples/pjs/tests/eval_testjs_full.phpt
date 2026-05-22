--TEST--
eval: test.js full result
--FILE--
<?php

use Pjs\Runtime;
use Pjs\Context;

$rt = new Runtime();
$ctx = new Context($rt);

var_dump($ctx->eval(file_get_contents('tests/test.js')));

?>
--EXPECTF--
object(Pjs\Value)%A (1) {
  ["value"]=>
  string(%d) "%A"
}
