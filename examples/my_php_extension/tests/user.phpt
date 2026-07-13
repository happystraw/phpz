--TEST--
MyPHPExt User models identity and enum-backed state
--FILE--
<?php

use MyPHPExt\Role;
use MyPHPExt\Status;
use MyPHPExt\User;

$user = new User(7, 'Alice');
var_dump($user->getId());
var_dump($user->label());
var_dump((string) $user);
var_dump($user->age);
var_dump($user->role === Role::User);
var_dump($user->status === Status::Active);
var_dump(User::MIN_AGE);

$admin = new User(9, 'Bob', 32, Role::Admin, Status::Inactive);
var_dump($admin->getId());
var_dump($admin->name);
var_dump($admin->age);
var_dump($admin->role === Role::Admin);
var_dump($admin->status === Status::Inactive);
--EXPECT--
int(7)
string(5) "Alice"
string(5) "Alice"
NULL
bool(true)
bool(true)
int(0)
int(9)
string(3) "Bob"
int(32)
bool(true)
bool(true)
