--TEST--
Call wrappers forward named arguments for functions, callables and methods
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\invokeArguments;

function check($actual, $expected): void {
    if ($actual !== $expected) throw new Exception(var_export([$actual, $expected], true));
}
function collect($first = 1, $second = 2, ...$extra) {
    return [$first, $second, $extra];
}
class Receiver {
    public function collect($first = 1, $second = 2, ...$extra) {
        return [$first, $second, $extra];
    }
    public static function staticcollect($first = 1, $second = 2, ...$extra) {
        return [$first, $second, $extra];
    }
}
$receiver = new Receiver;
$targets = [
    'callable' => 'collect',
    'function' => 'collect',
    'static' => [Receiver::class, 'staticcollect'],
    'method' => [$receiver, 'collect'],
    'object' => [$receiver, 'collect'],
    'object-static' => [$receiver, 'staticcollect'],
];
foreach ([false, true] as $guarded) {
    foreach ($targets as $mode => $target) {
        check(invokeArguments($mode, $target, [], null, $guarded), [1, 2, []]);
        check(invokeArguments($mode, $target, [10], null, $guarded), [10, 2, []]);
        check(invokeArguments($mode, $target, [], [], $guarded), [1, 2, []]);
        check(invokeArguments($mode, $target, [], ['second' => 20], $guarded), [1, 20, []]);
        check(invokeArguments($mode, $target, [], ['second' => 20, 'first' => 10], $guarded), [10, 20, []]);
        $named_params = ['second' => 20, 'extra' => new stdClass];
        check(invokeArguments($mode, $target, [10], $named_params, $guarded), [10, 20, ['extra' => $named_params['extra']]]);
        check(array_keys($named_params), ['second', 'extra']);
        check(invokeArguments($mode, $target, [], [10, 'second' => 20], $guarded), [10, 20, []]);
        check(invokeArguments($mode, $target, [10], [20, 'extra' => 30], $guarded), [10, 20, ['extra' => 30]]);
        foreach ([
            [[10], ['first' => 20], 'overwrites previous argument'],
            [[], ['second' => 20, 10], 'Cannot use positional argument after named argument'],
        ] as [$positional, $named_params, $message]) {
            try {
                invokeArguments($mode, $target, $positional, $named_params, $guarded);
                throw new Exception('invalid call accepted');
            } catch (Error $e) {
                check(str_contains($e->getMessage(), $message), true);
            }
        }
        echo $mode, $guarded ? ' guarded' : ' normal', ": passed\n";
    }
    foreach (['function', 'callable'] as $mode) {
        // Internal functions use the same named-argument path.
        check(invokeArguments($mode, 'greet', [], ['name' => 'Zig'], $guarded), 'Hello, Zig!');
        $value = 10;
        $named_params = ['by' => 3, 'value' => &$value];
        invokeArguments($mode, 'MyPHPExt\\increment', [], $named_params, $guarded);
        check($value, 13);
        check($named_params['value'], 13);
        try {
            invokeArguments($mode, 'greet', [], ['unknown' => 1], $guarded);
            throw new Exception('unknown name accepted');
        } catch (Error $e) {
            check(str_contains($e->getMessage(), 'Unknown named parameter'), true);
        }
    }
    $closure = fn ($first = 1, $second = 2) => [$first, $second];
    check(invokeArguments('callable', $closure, [], ['second' => 20], $guarded), [1, 20]);
    try {
        invokeArguments('callable', function ($message) { throw new RuntimeException($message); }, [], ['message' => 'named exception'], $guarded);
        throw new Exception('exception lost');
    } catch (RuntimeException $e) {
        check($e->getMessage(), 'named exception');
    }
}
echo "internal functions, references, closures and exceptions: passed\n";

class DiscardedResult {
    public static int $destroyed = 0;
    public function __destruct() { self::$destroyed++; }
}
foreach ([false, true] as $guarded) {
    foreach ([[], [10]] as $positional) {
        DiscardedResult::$destroyed = 0;
        $seen = [];
        $callback = function ($first = 1, $second = 2) use (&$seen) {
            $seen[] = [$first, $second];
            return new DiscardedResult;
        };
        $result = invokeArguments('callable-discard', $callback, $positional, ['second' => 20], $guarded);
        $first = $positional[0] ?? 1;
        check($seen, [[$first, 20], [$first, 2], [$first, 20], [$first, 2]]);
        check($result instanceof DiscardedResult, true);
        check(DiscardedResult::$destroyed, 3);
        unset($result);
        check(DiscardedResult::$destroyed, 4);
    }
    try {
        invokeArguments('callable-discard', function ($message) { throw new RuntimeException($message); }, [], ['message' => 'discard exception'], $guarded);
        throw new Exception('exception lost');
    } catch (RuntimeException $e) {
        check($e->getMessage(), 'discard exception');
    }
}
echo "explicit results, repeated discards and exception cleanup: passed\n";
?>
--EXPECT--
callable normal: passed
function normal: passed
static normal: passed
method normal: passed
object normal: passed
object-static normal: passed
callable guarded: passed
function guarded: passed
static guarded: passed
method guarded: passed
object guarded: passed
object-static guarded: passed
internal functions, references, closures and exceptions: passed
explicit results, repeated discards and exception cleanup: passed
