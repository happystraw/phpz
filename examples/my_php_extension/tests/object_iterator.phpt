--TEST--
Object iterators traverse values, release temporary iterators, and support native references
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\{iterateObject, incrementObjectIterator};
function check($ok) {
    if (!$ok) throw new RuntimeException('object iterator mismatch');
}
$expected = [['first', 10], [7, 20]];
$array = new ArrayIterator(['first' => 10, 7 => 20]);
check(iterateObject($array) === $expected);
check(iterateObject($array) === $expected);
check(iterateObject(new EmptyIterator) === []);
check(iterateObject((function () { yield 'first' => 10; yield 7 => 20; })()) === $expected);

class TrackedIterator extends ArrayIterator {
    public static int $destroyed = 0;
    public function __destruct() { ++self::$destroyed; }
}
class Source implements IteratorAggregate {
    public ?WeakReference $last = null;
    public function getIterator(): Traversable {
        $iterator = new TrackedIterator(['first' => 10, 7 => 20]);
        $this->last = WeakReference::create($iterator);
        return $iterator;
    }
}
$source = new Source;
check(iterateObject($source) === $expected);
check($source->last->get() === null && TrackedIterator::$destroyed === 1);
check(iterateObject($source, 1) === [['first', 10]]);
check($source->last->get() === null && TrackedIterator::$destroyed === 2);

incrementObjectIterator($array);
check($array->getArrayCopy() === ['first' => 11, 7 => 21]);
$maximum = new ArrayIterator([PHP_INT_MAX]);
try {
    incrementObjectIterator($maximum);
    throw new RuntimeException('integer overflow accepted');
} catch (Error $e) {
    check(str_contains($e->getMessage(), 'Overflow'));
}
check($maximum->getArrayCopy() === [PHP_INT_MAX]);
$values = [1, 2];
$generator = (function &() use (&$values) { foreach ($values as &$value) yield $value; })();
incrementObjectIterator($generator);
check($values === [2, 3]);
try {
    incrementObjectIterator((function () { yield 1; })());
    throw new RuntimeException('by-reference iteration accepted');
} catch (Exception $e) {
    check(str_contains($e->getMessage(), 'yields by-reference'));
}
try {
    iterateObject(new stdClass);
    throw new RuntimeException('non-traversable accepted');
} catch (TypeError $e) {}
echo "object iterators ok\n";
?>
--EXPECT--
object iterators ok
