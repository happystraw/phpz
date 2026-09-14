--TEST--
Zval cast and convert match PHP casts and preserve other reference owners
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\castValue;
use function MyPHPExt\Test\castReferenceValue;

function nativeCast($value, $type) {
    return match ($type) {
        'int' => (int) $value,
        'float' => (float) $value,
        'bool' => (bool) $value,
        'string' => (string) $value,
        'array' => (array) $value,
        'object' => (object) $value,
    };
}

function outcome(callable $fn, bool $throwWarnings): array {
    $warnings = [];
    set_error_handler(function ($level, $message) use (&$warnings, $throwWarnings) {
        if ($throwWarnings) throw new ErrorException($message, 0, $level);
        $warnings[] = [$level, $message];
        return true;
    });
    try {
        $value = $fn();
        return ['value', get_debug_type($value), var_export($value, true), $warnings];
    } catch (Throwable $e) {
        return ['exception', get_class($e), $e->getMessage(), $warnings];
    } finally {
        restore_error_handler();
    }
}

class StringValue {
    public function __toString(): string { return '123.75'; }
}
class ThrowingString {
    public function __toString(): string { throw new RuntimeException('cast failed'); }
}
class Properties {
    private int $hidden = 7;
    public string $visible = 'yes';
}

$resource = fopen('php://memory', 'r+');
$values = [null, false, true, 0, -42, PHP_INT_MAX, 3.75, -3.75, INF, NAN,
    '', '0', '00', '123.75tail', 'words', "a\0b", [], [1, 2], ['01' => 3, 2 => 'x'],
    new stdClass, new StringValue, new ThrowingString, new Properties, static fn() => 1, $resource];
$checks = 0;
$types = ['int', 'float', 'bool', 'string', 'array', 'object'];
foreach ([false, true] as $convert) {
    foreach ([false, true] as $throwWarnings) {
        foreach ($types as $type) {
            foreach ($values as $value) {
                $before = [get_debug_type($value), var_export($value, true)];
                $expected = outcome(fn() => nativeCast($value, $type), $throwWarnings);
                $actual = outcome(fn() => castValue($value, $type, $convert), $throwWarnings);
                if ($expected !== $actual || $before !== [get_debug_type($value), var_export($value, true)]) {
                    throw new RuntimeException("Mismatch: $type convert=" . (int) $convert);
                }
                ++$checks;
            }
        }
    }
}
fclose($resource);
echo "$checks comparisons passed\n";

foreach ([false, true] as $convert) {
    foreach ($types as $type) {
        foreach (['123.75', [], new ThrowingString] as $value) {
            $alias =& $value;
            $before = [get_debug_type($value), var_export($value, true)];
            $expected = outcome(fn() => nativeCast($value, $type), true);
            $actual = outcome(function () use (&$value, $type, $convert) {
                return castReferenceValue($value, $type, $convert);
            }, true);
            if ($expected !== $actual || $before !== [get_debug_type($alias), var_export($alias, true)]) {
                throw new RuntimeException("Reference mismatch: $type convert=" . (int) $convert);
            }
            unset($alias);
        }
    }
}
echo "reference checks passed\n";

$source = (object) ['value' => str_repeat('x', 32)];
$result = castValue($source, 'object', false);
if ($result !== $source) throw new RuntimeException('Object identity changed');
unset($source);
if ($result->value !== str_repeat('x', 32)) throw new RuntimeException('Object ownership lost');
unset($result);

$source = ['value' => str_repeat('y', 32)];
$result = castValue($source, 'array', false);
$result['value'] = 'changed';
if ($source['value'] !== str_repeat('y', 32)) throw new RuntimeException('Array source changed');
$result = castValue($source, 'object', false);
unset($source);
if ($result->value !== str_repeat('y', 32)) throw new RuntimeException('Converted object ownership lost');

$source = $result;
$result = castValue($source, 'array', false);
unset($source);
if ($result['value'] !== str_repeat('y', 32)) throw new RuntimeException('Converted array ownership lost');
unset($result);
echo "ownership checks passed\n";
?>
--EXPECT--
600 comparisons passed
reference checks passed
ownership checks passed
