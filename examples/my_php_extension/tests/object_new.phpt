--TEST--
Object new and tryNew construct arbitrary classes and clean up constructor failures
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\constructObject;

function check($condition) {
    if (!$condition) throw new RuntimeException('check failed');
}
class ParentTarget {
    public $value;
    function __construct($value) { $this->value = $value; }
}
class ChildTarget extends ParentTarget {}
class PrivateTarget { private function __construct() {} }
class FailingTarget {
    public static $weak;
    public static $destructed = false;
    function __construct() {
        self::$weak = WeakReference::create($this);
        throw new RuntimeException('constructor failed');
    }
    function __destruct() { self::$destructed = true; }
}
foreach ([false, true] as $guarded) {
    $object = constructObject(ChildTarget::class, ['value' => 42], $guarded);
    check($object instanceof ChildTarget && $object->value === 42);
    $weak = WeakReference::create($object);
    unset($object);
    check($weak->get() === null);

    check(constructObject(ArrayObject::class, [[1, 2]], $guarded)->getArrayCopy() === [1, 2]);
    check(constructObject(stdClass::class, ['ignored' => 42], $guarded) instanceof stdClass);
    foreach ([
        [PrivateTarget::class, Error::class, 'private'],
        [FailingTarget::class, RuntimeException::class, 'constructor failed'],
    ] as [$class, $errorClass, $message]) {
        try {
            constructObject($class, [], $guarded);
            throw new LogicException('expected constructor failure');
        } catch (Throwable $error) {
            check($error instanceof $errorClass && str_contains($error->getMessage(), $message));
        }
        unset($error);
    }
    check(FailingTarget::$weak->get() === null && !FailingTarget::$destructed);
}
echo "Object construction passed\n";
?>
--EXPECT--
Object construction passed
