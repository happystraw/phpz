--TEST--
Enum
--FILE--
<?php

use MyPHPExt\Status;
use MyPHPExt\Role;

echo 'Status cases: ';
foreach (Status::cases() as $case) {
    echo $case->name, '=', $case->value, ' ';
}
echo PHP_EOL;

echo 'Dumper on enum: ';
\MyPHPExt\Dumper::dump(Status::Active, Role::Admin);

?>
--EXPECT--
Status cases: Active=1 Inactive=0 
Dumper on enum: enum MyPHPExt\Status { Active = 1 }
enum MyPHPExt\Role { Admin = "admin" }
