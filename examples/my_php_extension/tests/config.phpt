--TEST--
MyPHPExt\Config exposes typed INI values
--INI--
my_php_extension.greeting=ZigRules
my_php_extension.max_users=42
my_php_extension.debug=1
my_php_extension.mode=fast
--FILE--
<?php

var_dump(
    MyPHPExt\Config::greeting(),
    MyPHPExt\Config::maxUsers(),
    MyPHPExt\Config::debugEnabled(),
    MyPHPExt\Config::mode(),
);

ini_set("my_php_extension.greeting", "Runtime");
var_dump(ini_set("my_php_extension.max_users", "99"));
ini_set("my_php_extension.debug", "0");
ini_set("my_php_extension.mode", "safe");

var_dump(
    MyPHPExt\Config::greeting(),
    MyPHPExt\Config::maxUsers(),
    MyPHPExt\Config::debugEnabled(),
    MyPHPExt\Config::mode(),
);

?>
--EXPECT--
string(8) "ZigRules"
int(42)
bool(true)
string(4) "fast"
bool(false)
string(7) "Runtime"
int(42)
bool(false)
string(4) "safe"
