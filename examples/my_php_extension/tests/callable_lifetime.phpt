--TEST--
Retained Callable supports reentrant calls, exception propagation and repeated magic calls
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use MyPHPExt\Test\GcNode;

function check($actual, $expected): void {
    if ($actual !== $expected) throw new Exception(var_export([$actual, $expected], true));
}

foreach ([false, true] as $guarded) {
    $node = null;
    $fail = false;
    $node = new GcNode(callback: static function (int $depth) use (&$node, &$fail, $guarded): int {
        if ($depth > 0) return $node->invokeCallback($depth - 1, !$guarded) + 1;
        if ($fail) throw new RuntimeException('inner exception');
        return 0;
    });
    check($node->invokeCallback(3, $guarded), 3);
    $fail = true;
    try {
        $node->invokeCallback(3, $guarded);
        throw new Exception('expected callback exception');
    } catch (RuntimeException $error) {
        check($error->getMessage(), 'inner exception');
    }
    unset($error);
    $fail = false;
    check($node->invokeCallback(2, $guarded), 2);
    unset($node);
}
echo "reentrant calls and exception propagation: passed\n";

class MagicTarget {
    public function __call(string $name, array $args): int { return $args[0] + 10; }
    public static function __callStatic(string $name, array $args): int { return $args[0] + 20; }
}

$node = new GcNode(callback: [new MagicTarget, 'missing']);
check($node->invokeCallback(3), 13);
check($node->invokeCallback(4, true), 14);
$node = new GcNode(callback: [MagicTarget::class, 'missingStatic']);
check($node->invokeCallback(3), 23);
check($node->invokeCallback(4, true), 24);
unset($node);
echo "repeated magic calls: passed\n";
?>
--EXPECT--
reentrant calls and exception propagation: passed
repeated magic calls: passed
