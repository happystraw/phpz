--TEST--
Interface
--FILE--
<?php

use MyPHPExt\User;

echo 'User implements Identifiable: ', (is_subclass_of(User::class, 'MyPHPExt\\Identifiable') ? 'yes' : 'no'), PHP_EOL;

?>
--EXPECT--
User implements Identifiable: yes
