--TEST--
Error class
--FILE--
<?php

use MyPHPExt\MyError;

echo 'MyError is Exception subclass: ', (is_subclass_of(MyError::class, \Exception::class) ? 'yes' : 'no'), PHP_EOL;

?>
--EXPECT--
MyError is Exception subclass: yes
