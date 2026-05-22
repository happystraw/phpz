--TEST--
Constants
--FILE--
<?php

echo 'MY_EXT_VERSION: ', MY_EXT_VERSION, PHP_EOL;
echo 'MyPHPExt\VERSION: ', \MyPHPExt\VERSION, PHP_EOL;
echo 'User::MIN_AGE: ', \MyPHPExt\User::MIN_AGE, PHP_EOL;

?>
--EXPECT--
MY_EXT_VERSION: 1.0.0
MyPHPExt\VERSION: 1
User::MIN_AGE: 0
