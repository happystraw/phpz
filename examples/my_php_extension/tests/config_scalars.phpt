--TEST--
MyPHPExt INI scalars preserve Zend boolean and string semantics
--INI--
my_php_extension.max_users=2K
--FILE--
<?php
var_dump(MyPHPExt\Config::maxUsers());
foreach (["1foo", "1.5", " true ", "yes", "-2", "0foo", "true\0x"] as $value) {
    ini_set("my_php_extension.debug", $value);
    var_dump(MyPHPExt\Config::debugEnabled());
}
foreach (["a\0b", "\0", ""] as $value) {
    ini_set("my_php_extension.greeting", $value);
    $actual = MyPHPExt\Config::greeting();
    var_dump($actual === ini_get("my_php_extension.greeting"), strlen($actual), bin2hex($actual));
}
ini_restore("my_php_extension.greeting");
var_dump(MyPHPExt\Config::greeting());
?>
--EXPECT--
int(2048)
bool(true)
bool(true)
bool(false)
bool(true)
bool(true)
bool(false)
bool(false)
bool(true)
int(3)
string(6) "610062"
bool(true)
int(1)
string(2) "00"
bool(true)
int(0)
string(0) ""
string(5) "Hello"
