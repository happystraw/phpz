--TEST--
MyPHPExt\Dumper renders representative PHP values
--FILE--
<?php

MyPHPExt\Dumper::dump(
    1,
    "hello",
    true,
    null,
    ["name" => "phpz", "nested" => [2, false]],
    new MyPHPExt\Counter(),
    new MyPHPEXT\User(1, 'admin'),
    MyPHPExt\Role::Admin,
);

?>
--EXPECTF--
int(1)
string(5) "hello"
bool(true)
NULL
array(2) {
  ["name"] =>
  string(4) "phpz"
  ["nested"] =>
  array(2) {
    [0] =>
    int(2)
    [1] =>
    bool(false)
  }
}
class MyPHPExt\Counter#%d (0) {
}
class MyPHPExt\User#%d (5) {
  protected $id =>
  int(1)
  public $name =>
  string(5) "admin"
  public $age =>
  NULL
  public $role =>
  enum MyPHPExt\Role { User = "user" }
  public $status =>
  enum MyPHPExt\Status { Active = 1 }
}
enum MyPHPExt\Role { Admin = "admin" }
