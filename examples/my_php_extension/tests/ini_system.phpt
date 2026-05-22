--TEST--
INI access=system: ini_set blocked, only php.ini
--FILE--
<?php

echo "default (php.ini):  ", ini_get("my_php_extension.max_users"), "\n";

$r = @ini_set("my_php_extension.max_users", "999");
echo "ini_set result:     ", var_export($r, true), "\n";
echo "after ini_set:      ", ini_get("my_php_extension.max_users"), "\n";

?>
--EXPECT--
default (php.ini):  100
ini_set result:     false
after ini_set:      100
