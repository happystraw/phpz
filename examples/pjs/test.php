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
    echo 'exception:  ', 'class: ', $e::class, ', error: ',  $e->getTraceAsString(), PHP_EOL;
}
echo '--------', PHP_EOL;

// Load and execute JavaScript code from test.js file
echo '-------- Loading test.js --------', PHP_EOL;
$jsFile = __DIR__ . '/test.js';
if (file_exists($jsFile)) {
    $jsCode = file_get_contents($jsFile);
    echo 'eval:   test.js', PHP_EOL;
    echo 'result: ', PHP_EOL;
    $result = $ctx->eval($jsCode);
    var_dump($result);

    // Test calling functions defined in test.js individually
    echo '--------', PHP_EOL;
    echo 'eval:   greet("World")', PHP_EOL;
    echo 'result: ';
    var_dump($ctx->eval('greet("World")'));

    echo '--------', PHP_EOL;
    echo 'eval:   fibonacci(8)', PHP_EOL;
    echo 'result: ';
    var_dump($ctx->eval('fibonacci(8)'));

    echo '--------', PHP_EOL;
    echo 'eval:   person.introduce()', PHP_EOL;
    echo 'result: ';
    var_dump($ctx->eval('testResults.person.introduce()'));
} else {
    echo 'test.js file not found!', PHP_EOL;
}

