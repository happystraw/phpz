--TEST--
newWith releases the object when the constructor throws
--FILE--
<?php

try {
    MyPHPExt\tryCreateInvalidUser();
} catch (TypeError $e) {
    echo get_class($e), PHP_EOL;
    echo str_contains($e->getMessage(), 'must be of type string') ? 'message ok' : $e->getMessage(), PHP_EOL;
}

?>
--EXPECT--
TypeError
message ok
