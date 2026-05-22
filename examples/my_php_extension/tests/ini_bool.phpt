--TEST--
INI access=user: ini_set works, default + override + ini_set
--INI--
my_php_extension.debug=1
--FILE--
<?php

echo "default in php.ini: 0\n";
echo "via -d override:    ", ini_get("my_php_extension.debug"), "\n";

$r = ini_set("my_php_extension.debug", "0");
echo "ini_set result:     ", var_export($r, true), "\n";
echo "after ini_set:      ", ini_get("my_php_extension.debug"), "\n";

?>
--EXPECT--
default in php.ini: 0
via -d override:    1
ini_set result:     '1'
after ini_set:      0
