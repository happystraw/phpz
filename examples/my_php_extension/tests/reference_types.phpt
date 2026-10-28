--TEST--
Reference assignments honor all property type sources and consume rejected values
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\setReference;
use function MyPHPExt\Test\setReferenceSelf;
function check($ok) {
    if (!$ok) throw new RuntimeException('typed reference mismatch');
}
class IntBox { public int $value = 1; }
class UnionBox { public int|string $value = 2; }
$int = new IntBox;
$union = new UnionBox;
$ref =& $int->value;
setReference($ref, 'string', '123');
$union->value =& $int->value;
check($ref === 123 && $int->value === 123 && $union->value === 123);
setReferenceSelf($ref);
check($ref === 123);

// int requires conversion, while int|string preserves the string.
try {
    setReference($ref, 'string', '456');
    throw new RuntimeException('expected conflicting type conversion');
} catch (TypeError $e) {
    check($ref === 123 && $int->value === 123 && $union->value === 123);
}
unset($e);

class Rejected {
    public static int $destroyed = 0;
    public function __destruct() { ++self::$destroyed; }
}
foreach (['string', 'str', 'array', 'object', 'mixed'] as $kind) {
    $value = match ($kind) {
        'string', 'str' => str_repeat('invalid', 30),
        'array' => ['invalid'],
        default => new Rejected,
    };
    if (is_object($value)) $weak = WeakReference::create($value);
    try {
        setReference($ref, $kind, $value);
        throw new RuntimeException('expected type rejection');
    } catch (TypeError $e) {
        check($ref === 123 && $int->value === 123 && $union->value === 123);
    }
    unset($value, $e);
    if (isset($weak)) {
        check($weak->get() === null);
        unset($weak);
    }
}
check(Rejected::$destroyed === 2);
// Retaining the reference must not lose the remaining property's type source.
unset($int);
setReference($ref, 'string', 'allowed');
check($union->value === 'allowed');
echo "reference types ok\n";
?>
--EXPECT--
reference types ok
