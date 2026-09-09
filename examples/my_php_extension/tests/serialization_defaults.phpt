--TEST--
MyPHPExt native backing denies serialization while standard PHP properties retain their behavior
--EXTENSIONS--
my_php_extension
--FILE--
<?php
class SerializationChild extends MyPHPExt\Collection {
    public function __serialize(): array { throw new LogicException('serialize hook called'); }
    public function __unserialize(array $data): void { throw new LogicException('unserialize hook called'); }
}

foreach ([
    new MyPHPExt\Collection(['answer' => 42]),
    new MyPHPExt\Counter(42),
    new MyPHPExt\Test\GcNode(),
    new SerializationChild(),
] as $object) {
    $class = $object::class;
    try {
        serialize($object);
        echo "unexpected serialization success\n";
    } catch (Throwable $e) {
        echo $e->getMessage(), "\n";
    }
    foreach (['O:%d:"%s":0:{}', 'C:%d:"%s":0:{}'] as $format) {
        try {
            unserialize(sprintf($format, strlen($class), $class));
            echo "unexpected unserialization success\n";
        } catch (Throwable $e) {
            echo $e->getMessage(), "\n";
        }
    }
}

echo "standard PHP properties\n";
$user = unserialize(serialize(new MyPHPExt\User(7, 'Alice', 32)));
var_dump($user->getId(), $user->name, $user->age, $user->role === MyPHPExt\Role::User);
?>
--EXPECT--
Serialization of 'MyPHPExt\Collection' is not allowed
Unserialization of 'MyPHPExt\Collection' is not allowed
Unserialization of 'MyPHPExt\Collection' is not allowed
Serialization of 'MyPHPExt\Counter' is not allowed
Unserialization of 'MyPHPExt\Counter' is not allowed
Unserialization of 'MyPHPExt\Counter' is not allowed
Serialization of 'MyPHPExt\Test\GcNode' is not allowed
Unserialization of 'MyPHPExt\Test\GcNode' is not allowed
Unserialization of 'MyPHPExt\Test\GcNode' is not allowed
Serialization of 'SerializationChild' is not allowed
Unserialization of 'SerializationChild' is not allowed
Unserialization of 'SerializationChild' is not allowed
standard PHP properties
int(7)
string(5) "Alice"
int(32)
bool(true)
