--TEST--
Constant reads preserve Zend resolution, class scope and borrowed value ownership
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\{readConstant, readClassConstant, checkConstantMetadata};
function check($condition) {
    if (!$condition) throw new RuntimeException('check failed');
}
define('ReadTest\TEXT', "a\0b");
define('ReadTest\NIL', null);
check(readConstant('\\readtest\\TEXT', false) === "a\0b");
check(readConstant('ReadTest\NIL', false) === null);

class ConstantParent { public const VALUES = [1, 2]; private const SECRET = 42; protected const HIDDEN = 7; }
class ConstantChild extends ConstantParent {}
class BrokenConstant { const VALUE = MISSING_CONSTANT_VALUE; }
checkConstantMetadata();
$values = readClassConstant(ConstantChild::class, 'VALUES', false);
$values[] = 3;
check(ConstantParent::VALUES === [1, 2]);
check(readConstant('ConstantChild::VALUES', false) === [1, 2]);
check(readClassConstant(ConstantParent::class, 'SECRET', false) === 42);

foreach ([false, true] as $silent) {
    foreach ([
        fn() => readConstant('MISSING_CONSTANT', $silent),
        fn() => readClassConstant(ConstantChild::class, 'SECRET', $silent),
        fn() => readClassConstant(ConstantChild::class, 'MISSING', $silent),
    ] as $read) {
        try { $read(); throw new LogicException('expected lookup failure'); }
        catch (Error $error) { check(str_contains($error->getMessage(), $silent ? 'ConstantNotFound' : 'constant')); }
    }
    try { readClassConstant(BrokenConstant::class, 'VALUE', $silent); throw new LogicException('expected evaluation error'); }
    catch (Error $error) { check(str_contains($error->getMessage(), 'MISSING_CONSTANT_VALUE')); }
}
spl_autoload_register(function ($name) { throw new RuntimeException('autoload failed'); });
try { readConstant('UnloadedConstantClass::VALUE', true); throw new LogicException('expected autoload error'); }
catch (RuntimeException $error) { check($error->getMessage() === 'autoload failed'); }
echo "Constant reads passed\n";
?>
--EXPECT--
Constant reads passed
