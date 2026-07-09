--TEST--
INI values read via Zig typed getters, with ini_set
--INI--
my_php_extension.greeting=ZigRules
my_php_extension.max_users=42
my_php_extension.debug=1
my_php_extension.mode=fast
--FILE--
<?php

echo "--- default/override ---\n";
echo "greeting:  ", iniGetGreeting(), "\n";
echo "max_users: ", iniGetMaxUsers(), "\n";
echo "debug:     ", var_export(iniGetDebug(), true), "\n";
echo "mode:      ", iniGetMode(), "\n";

echo "\n--- after ini_set ---\n";
ini_set("my_php_extension.greeting", "Runtime");
var_dump(ini_set("my_php_extension.max_users", "99")); // .system → blocked
ini_set("my_php_extension.debug", "0");
ini_set("my_php_extension.mode", "safe");

echo "greeting:  ", iniGetGreeting(), "\n";
echo "max_users: ", iniGetMaxUsers(), "\n";
echo "debug:     ", var_export(iniGetDebug(), true), "\n";
echo "mode:      ", iniGetMode(), "\n";

?>
--EXPECT--
--- default/override ---
greeting:  ZigRules
max_users: 42
debug:     true
mode:      fast

--- after ini_set ---
bool(false)
greeting:  Runtime
max_users: 42
debug:     false
mode:      safe
