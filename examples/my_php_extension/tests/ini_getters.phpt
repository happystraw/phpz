--TEST--
INI scalar getters preserve numeric parsing and forced updates bypass access restrictions
--EXTENSIONS--
my_php_extension
--FILE--
<?php
MyPHPExt\Test\makeFnClosure('ini_scalars')();
var_dump(ini_get('my_php_extension.greeting'), ini_get('my_php_extension.max_users'));
?>
--EXPECT--
string(3) "1.5"
string(3) "200"
