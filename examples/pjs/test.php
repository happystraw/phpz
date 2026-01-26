<?php

declare(strict_types=1);

use Pjs\Runtime;
use Pjs\Context;
// use Pjs\Value;
use Pjs\Exception;

$rt = new Runtime();
$ctx = new Context($rt);
echo '-------- Tests --------', PHP_EOL;
echo 'eval:   new Date', PHP_EOL;
echo 'result: ';
var_dump($ctx->eval("new Date"));
echo '--------', PHP_EOL;
echo 'eval:   1+1', PHP_EOL;
echo 'result: ';
var_dump($ctx->eval("1+1"));
echo '--------', PHP_EOL;
try {
    echo 'eval:       a()', PHP_EOL;
    $ctx->eval("a()");
} catch(Exception $e) {
    echo 'exception:  ', 'class: ', $e::class, ', error: ',  $e->getMessage(), PHP_EOL;
}

