--TEST--
User class methods
--FILE--
<?php

use MyPHPExt\User;

$user = new User("Rick", 18);
echo 'User::getId: ', $user->getId(), PHP_EOL;
echo '__toString: ', (string)$user, PHP_EOL;
$user->handle(42);
echo 'name: ', $user->name, PHP_EOL;
echo 'age: ', $user->age, PHP_EOL;

?>
--EXPECT--
AbstractEntity::onLoad: getId() = 9527
User::getId: 9527
__toString: User(Rick)
Rick(18).handle(42)
name: Rick
age: 18
