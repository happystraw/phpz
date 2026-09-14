--TEST--
Object clone dispatches native handlers and releases failed clones
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\cloneObject;

function check($condition) {
    if (!$condition) throw new RuntimeException('check failed');
}
$source = (object) ['value' => 42];
$copy = cloneObject($source);
check($copy !== $source && $copy == $source);

$source = new ArrayObject([1, 2]);
$copy = cloneObject($source);
$copy[] = 3;
check($source->getArrayCopy() === [1, 2] && $copy->getArrayCopy() === [1, 2, 3]);

$source = new MyPHPExt\BigInteger(42);
$copy = cloneObject($source);
unset($source);
check($copy->value() === '42');

try {
    cloneObject(new ReflectionClass(stdClass::class));
    throw new LogicException('expected uncloneable error');
} catch (Error $error) {
    check(str_starts_with($error->getMessage(), 'Uncloneable at '));
}
unset($error);

class ThrowsOnClone {
    public static $weak;
    function __clone() {
        self::$weak = WeakReference::create($this);
        throw new RuntimeException('clone failed');
    }
}
$source = new ThrowsOnClone;
try {
    cloneObject($source);
    throw new LogicException('expected clone exception');
} catch (RuntimeException $error) {
    check($error->getMessage() === 'clone failed');
}
// Release the exception trace's reference to the failed clone.
unset($error);
check(ThrowsOnClone::$weak->get() === null);
echo "Object cloning passed\n";
?>
--EXPECT--
Object cloning passed
