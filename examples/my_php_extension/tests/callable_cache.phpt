--TEST--
Owned callable cache preserves private method scope, named arguments and discarded-result exceptions
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use MyPHPExt\Test\GcNode;
use function MyPHPExt\Test\invokeArguments;
function check($condition) { if (!$condition) throw new RuntimeException('check failed'); }
class PrivateTarget {
    private function compute($value) { return $value + 10; }
    public function retained() { return new GcNode(callback: [$this, 'compute']); }
}
$node = (new PrivateTarget)->retained();
check($node->invokeCallback(2) === 12);
check($node->invokeCallback(3, true) === 13);
unset($node);
foreach ([false, true] as $guarded) {
    check(invokeArguments('cache', static fn($first, $second) => [$first, $second], [1], ['second' => 2], $guarded) === [1, 2]);
    try {
        invokeArguments('cache', static fn($first) => $first, [1], ['first' => 2], $guarded);
        throw new RuntimeException('expected duplicate argument error');
    } catch (Error $e) {
        check(str_contains($e->getMessage(), 'overwrites'));
    }
    try {
        invokeArguments('cache-discard', static fn() => new class {
            public function __destruct() { throw new RuntimeException('cache destructor'); }
        }, [], null, $guarded);
        throw new LogicException('expected destructor exception');
    } catch (RuntimeException $e) {
        check($e->getMessage() === 'cache destructor');
    }
}
echo "cache scope, named arguments and cleanup passed\n";
?>
--EXPECT--
cache scope, named arguments and cleanup passed
