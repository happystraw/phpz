--TEST--
Init Context with invalid Runtime
--FILE--
<?php

use Pjs\Runtime;
use Pjs\Context;

var_dump(new Context(new Runtime));

try {
    var_dump(new Context(new stdClass));
} catch (TypeError $e) {
    echo "TypeError: " . $e->getMessage() . PHP_EOL;
}

?>
--EXPECTF--
object(Pjs\Context)#%A (0) {
}
TypeError: Pjs\Context::__construct(): Argument #1 ($runtime) must be instance of Pjs\Runtime, stdClass given
