--TEST--
Retained Callable survives its creation scope and is released with its final owner
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use MyPHPExt\Test\GcNode;

function check($actual, $expected): void {
    if ($actual !== $expected) throw new Exception(var_export([$actual, $expected], true));
}

class RetainedState {
    public static int $destroyed = 0;
    public int $value = 10;
    public function __destruct() { self::$destroyed++; }
}

function makeRetained(): array {
    $state = new RetainedState;
    $callback = static fn (int $step): int => $state->value += $step;
    return [
        new GcNode(callback: $callback),
        new GcNode(callback: $callback),
        WeakReference::create($callback),
        WeakReference::create($state),
    ];
}

[$first, $second, $callbackWeak, $stateWeak] = makeRetained();
check($first->invokeCallback(2), 12);
unset($first);
check($callbackWeak->get() instanceof Closure, true);
check(RetainedState::$destroyed, 0);
check($second->invokeCallback(3, true), 15);
check($second->invokeCallback(4), 19);
unset($second);
check($callbackWeak->get(), null);
check($stateWeak->get(), null);
check(RetainedState::$destroyed, 1);
echo "creation scope, shared owners and final release: passed\n";
?>
--EXPECT--
creation scope, shared owners and final release: passed
