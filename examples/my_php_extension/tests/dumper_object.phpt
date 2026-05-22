--TEST--
Dumper::dump with objects
--FILE--
<?php

echo "--- default user ---\n";
\MyPHPExt\Dumper::dump(\MyPHPExt\getDefaultUser());

echo "--- multiple args ---\n";
\MyPHPExt\Dumper::dump(42, "text", [1, 2, 3], new stdClass());

echo "--- anonymous class ---\n";
$user = new class {
    public string $name = 'Alice';
    public int $age = 30;
    protected string $role = 'admin';
    private string $secret = 'xyz';
};
\MyPHPExt\Dumper::dump($user);

?>
--EXPECTF--
--- default user ---
AbstractEntity::onLoad: getId() = 9527
class MyPHPExt\User%A (2) {
  public $name =>
  string(7) "Default"
  public $age =>
  int(25)
}
--- multiple args ---
int(42)
string(4) "text"
array(3) {
  [0] =>
  int(1)
  [1] =>
  int(2)
  [2] =>
  int(3)
}
class stdClass%A (0) {
}
--- anonymous class ---
class class@anonymous%A (4) {
  public $name =>
  string(5) "Alice"
  public $age =>
  int(30)
  protected $role =>
  string(5) "admin"
  private $secret =>
  string(3) "xyz"
}
