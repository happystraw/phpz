--TEST--
Closure captures release once and expose native reference cycles to Zend GC
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\makeCounter;
use function MyPHPExt\makeReference;

function check($actual, $expected): void {
    if ($actual !== $expected) throw new Exception(var_export([$actual, $expected], true));
}
class ClosureCapture {
    public static int $destroyed = 0;
    public mixed $link = null;
    function __destruct() { ++self::$destroyed; }
}

$held = new ClosureCapture();
$callback = makeCounter(held: $held);
$copy = clone $callback;
$weak = WeakReference::create($held);
unset($held, $callback);
check(ClosureCapture::$destroyed, 0);
check($copy(), 1);
unset($copy);
check($weak->get(), null);
check(ClosureCapture::$destroyed, 1);

$callback = makeCounter(held: new ClosureCapture());
unset($callback);
check(ClosureCapture::$destroyed, 2);
echo "uncalled capture and shared owner lifetime: passed\n";

foreach (['object', 'array', 'callable'] as $kind) {
    $holder = new ClosureCapture();
    $held = match ($kind) {
        'object' => $holder,
        'array' => [$holder],
        'callable' => static fn () => $holder,
    };
    $callback = makeCounter(held: $held);
    $holder->link = $callback;
    $hw = WeakReference::create($holder);
    $cw = WeakReference::create($callback);
    $ow = WeakReference::create((new ReflectionFunction($callback))->getClosureThis());
    unset($holder, $held, $callback);
    gc_collect_cycles();
    check([$hw->get(), $cw->get(), $ow->get()], [null, null, null]);
}
check(ClosureCapture::$destroyed, 5);
$value = [];
$callback = makeReference($value);
$value['callback'] = $callback;
$cw = WeakReference::create($callback);
$ow = WeakReference::create((new ReflectionFunction($callback))->getClosureThis());
unset($value, $callback);
gc_collect_cycles();
check([$cw->get(), $ow->get()], [null, null]);
echo "object, array, callable and reference cycles: passed\n";

?>
--EXPECT--
uncalled capture and shared owner lifetime: passed
object, array, callable and reference cycles: passed
