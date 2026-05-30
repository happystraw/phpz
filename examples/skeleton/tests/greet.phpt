--TEST--
greet($name) returns a personalized greeting
--FILE--
<?php

echo greet("Zig");
echo "\n";
echo greet("PHP");
--EXPECT--
Hello, Zig!
Hello, PHP!
