--TEST--
Object init dispatches factories without constructors and preserves initialization errors
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\initObject;

function check($condition) {
    if (!$condition) throw new RuntimeException('check failed');
}
class Target {
    public $value = Dependency::VALUE;
    function __construct() { throw new LogicException('constructor must not run'); }
}
spl_autoload_register(function ($name) {
    if ($name === 'Dependency') { class Dependency { const VALUE = 42; } }
    if ($name === 'MissingDependency') throw new RuntimeException('dependency failed');
});
$object = initObject(Target::class);
check($object instanceof Target && $object->value === 42);
$weak = WeakReference::create($object);
unset($object);
check($weak->get() === null);

check(initObject(stdClass::class) instanceof stdClass);
check(initObject(ArrayObject::class)->getArrayCopy() === []);
check(initObject(MyPHPExt\Test\NewValue::class)->values() === [0, 0]);

abstract class AbstractTarget {}
class UnresolvedTarget { public $value = MissingDependency::VALUE; }
foreach ([
    [AbstractTarget::class, Error::class, 'Cannot instantiate abstract class'],
    [UnresolvedTarget::class, RuntimeException::class, 'dependency failed'],
] as [$class, $errorClass, $message]) {
    try {
        initObject($class);
        throw new LogicException('expected initialization failure');
    } catch (Throwable $error) {
        check($error instanceof $errorClass && str_contains($error->getMessage(), $message));
    }
}
echo "Object initialization passed\n";
?>
--EXPECT--
Object initialization passed
