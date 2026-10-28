--TEST--
Reference creation, return ownership, replacement, and self-assignment
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\createReference;
use function MyPHPExt\Test\createReferenceCopy;
use function MyPHPExt\Test\setReference;
use function MyPHPExt\Test\setReferenceSelf;

function check($ok) {
    if (!$ok) throw new RuntimeException('reference value mismatch');
}
$resource = fopen('php://memory', 'w+');
$object = new stdClass;
$values = [
    'null' => null, 'int' => 42, 'float' => 1.5, 'bool' => true,
    'string' => str_repeat("a\0b", 30), 'str' => str_repeat('owned', 30),
    'array' => ['value' => 42], 'object' => $object, 'resource' => $resource,
    'mixed' => ['mixed' => true],
];
foreach ($values as $kind => $value) {
    $ref =& createReference($kind, $value);
    check($ref === $value);
    $alias =& $ref;
    setReferenceSelf($ref);
    check($ref === $value && $alias === $value);
    $copy =& createReferenceCopy($ref);
    $copy = 'independent';
    check($ref === $value);
    setReference($ref, 'null', null);
    check($ref === null && $alias === null);
    setReference($ref, $kind, $value);
    check($alias === $value);
    unset($ref, $alias, $copy);
    // The function result may also be discarded or read by value.
    createReference($kind, $value);
    check(createReference($kind, $value) === $value);
}
$ref =& createReference('array', [1]);
$copy = $ref;
$copy[] = 2;
check($ref === [1]);
unset($ref, $copy);

class Watched {
    public static int $destroyed = 0;
    public function __destruct() { ++self::$destroyed; }
}
$ref =& createReference('object', new Watched);
$alias =& $ref;
check(Watched::$destroyed === 0);
setReference($ref, 'int', 7);
check(Watched::$destroyed === 1 && $alias === 7);
unset($ref, $alias);
createReference('object', new Watched);
check(Watched::$destroyed === 2);

class ThrowingDestructor {
    public function __destruct() { throw new RuntimeException('destructor'); }
}
$ref =& createReference('object', new ThrowingDestructor);
try {
    setReference($ref, 'string', str_repeat('replacement', 30));
    throw new LogicException('exception missing');
} catch (RuntimeException $e) {
    check($e->getMessage() === 'destructor');
}
check($ref === str_repeat('replacement', 30));
unset($ref, $e);
check((new ReflectionFunction('MyPHPExt\\Test\\createReference'))->returnsReference());
fclose($resource);
echo "reference values ok\n";
?>
--EXPECT--
reference values ok
