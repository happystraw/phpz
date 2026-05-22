--TEST--
eval: a() - ReferenceError exception
--FILE--
<?php

use Pjs\Runtime;
use Pjs\Context;
use Pjs\Exception;

$rt = new Runtime();
$ctx = new Context($rt);

try {
    $ctx->eval("a()");
} catch (Exception $e) {
    echo 'class: ', $e::class, "\n";
    echo 'error: ', $e->getMessage(), "\n";
}

?>
--EXPECT--
class: Pjs\Exception
error: ReferenceError: a is not defined
