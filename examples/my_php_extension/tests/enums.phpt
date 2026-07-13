--TEST--
MyPHPExt backed enums and Identifiable contract
--FILE--
<?php

use MyPHPExt\Identifiable;
use MyPHPExt\Role;
use MyPHPExt\Status;
use MyPHPExt\User;

var_dump(Status::Inactive->value);
var_dump(Status::Active->value);
var_dump(Role::User->value);
var_dump(Role::Admin->value);
var_dump(array_map(static fn (Status $case): string => $case->name, Status::cases()));
var_dump(is_subclass_of(User::class, Identifiable::class));
--EXPECT--
int(0)
int(1)
string(4) "user"
string(5) "admin"
array(2) {
  [0]=>
  string(8) "Inactive"
  [1]=>
  string(6) "Active"
}
bool(true)
