--TEST--
Typed expectArg/expectArgs outputs, integer ranges, f32 narrowing and nullable/optional states
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\typedArgument as parse;
use function MyPHPExt\Test\checkStringArguments;

function same($expected, $actual): void {
    if (is_float($expected) && is_nan($expected) && is_float($actual) && is_nan($actual)) return;
    if ($expected !== $actual) throw new RuntimeException('Unexpected parsed value');
}
function fails(string $class, callable $call): void {
    try { $call(); } catch (Throwable $e) {
        if (get_class($e) !== $class || !str_contains($e->getMessage(), 'Argument #3')) throw $e;
        return;
    }
    throw new RuntimeException("Expected $class");
}

$ranges = [
    'i8' => [-128, 127], 'i16' => [-32768, 32767],
    'i32' => [-2147483648, 2147483647], 'i64' => [PHP_INT_MIN, PHP_INT_MAX],
    'isize' => [PHP_INT_MIN, PHP_INT_MAX], 'u8' => [0, 255], 'u16' => [0, 65535],
    'u32' => [0, min(PHP_INT_MAX, 4294967295)],
    'u64' => [0, PHP_INT_MAX], 'usize' => [0, PHP_INT_MAX],
];
foreach ([true, false] as $single) {
    foreach ($ranges as $type => [$min, $max]) {
        foreach ([$min, 0, 1, $max] as $value) same($value, parse($type, $single, $value));
        if ($min > PHP_INT_MIN) fails(ValueError::class, fn() => parse($type, $single, $min - 1));
        if ($max < PHP_INT_MAX) fails(ValueError::class, fn() => parse($type, $single, $max + 1));
        foreach (['12', 12.0, false, [], null] as $bad) {
            fails(TypeError::class, fn() => parse($type, $single, $bad));
        }
    }
    foreach (['f32', 'f64'] as $type) {
        foreach ([0.0, -0.0, 1.5, 0.1, INF, -INF, NAN, 1.0e-46, 16777217.0] as $value) {
            $expected = $type === 'f32' ? unpack('f', pack('f', $value))[1] : $value;
            same($expected, parse($type, $single, $value));
        }
        same(-INF, fdiv(1.0, parse($type, $single, -0.0)));
        foreach ([1, '1.5', false, [], null] as $bad) fails(TypeError::class, fn() => parse($type, $single, $bad));
    }
    $maxFloat = 3.4028234663852886e38;
    same($maxFloat, parse('f32', $single, $maxFloat));
    same(-$maxFloat, parse('f32', $single, -$maxFloat));
    foreach ([$maxFloat * 2, -$maxFloat * 2, PHP_FLOAT_MAX] as $bad) {
        fails(ValueError::class, fn() => parse('f32', $single, $bad));
    }

    foreach (['string', 'str', 'zval'] as $type) {
        foreach (['', 'x', "a\0b", "\xff\xfe", str_repeat('owned', 30)] as $value) {
            same($value, parse($type, $single, $value));
            same(true, checkStringArguments($value));
        }
        foreach ([1, false, [], new stdClass] as $bad) fails(TypeError::class, fn() => parse($type, $single, $bad));
    }

    $resource = fopen('php://memory', 'r+');
    $values = ['u8' => 42, 'f32' => 1.5, 'string' => 'text', 'str' => 'text', 'zval' => 'text',
        'int-zval' => -500, 'float-zval' => PHP_FLOAT_MAX, 'bool-zval' => true,
        'array-zval' => ['key' => 42], 'object-zval' => new stdClass, 'resource-zval' => $resource];
    foreach ($values as $type => $value) {
        foreach (['', 'nullable-', 'optional-', 'both-'] as $prefix) same($value, parse($prefix . $type, $single, $value));
        same(null, parse('nullable-' . $type, $single, null));
        same(null, parse('both-' . $type, $single, null));
        same('omitted', parse('optional-' . $type, $single));
        same('omitted', parse('both-' . $type, $single));
        fails(TypeError::class, fn() => parse('optional-' . $type, $single, null));
    }
    fclose($resource);
}
same(42, parse(value: 42, single: true, mode: 'u8'));
echo "typed arguments passed\n";
?>
--EXPECT--
typed arguments passed
