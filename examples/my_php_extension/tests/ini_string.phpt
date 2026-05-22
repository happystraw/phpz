--TEST--
INI access=all: ini_set works, default + override + ini_set
--INI--
my_php_extension.greeting=Override
--FILE--
<?php

echo "default in php.ini: Hello\n";
echo "via -d override:    ", ini_get("my_php_extension.greeting"), "\n";

$r = ini_set("my_php_extension.greeting", "Runtime");
echo "ini_set result:     ", var_export($r, true), "\n";
echo "after ini_set:      ", ini_get("my_php_extension.greeting"), "\n";

?>
--EXPECT--
default in php.ini: Hello
via -d override:    Override
ini_set result:     'Override'
after ini_set:      Runtime
