--TEST--
User class methods
--FILE--
<?php

use MyPHPExt\User;

$user = new User("Rick", 18);
echo 'User::getId: ', $user->getId(), PHP_EOL;
echo '__toString: ', (string)$user, PHP_EOL;
$user->handle(42);
echo 'handle() called successfully', PHP_EOL;

?>
--EXPECT--
AbstractEntity::onLoad: getId() = 9527
User::getId: 9527
__toString: User(Rick)
handle() called successfully
