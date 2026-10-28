--TEST--
Making a reference preserves values, aliases, and payload ownership
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\makeReference;

function check($ok) {
    if (!$ok) throw new RuntimeException('make reference mismatch');
}
$stream = fopen('php://memory', 'w+');
foreach ([null, true, 42, 1.5, str_repeat("a\0b", 30), [1, 2], new stdClass, $stream] as $value) {
    $ref =& makeReference($value);
    check($ref === $value);
    $alias =& $ref;
    $ref = 'changed';
    check($alias === 'changed' && $value !== 'changed');
    unset($ref, $alias);
}
fclose($stream);

class Watched {
    public static int $destroyed = 0;
    public function __destruct() { ++self::$destroyed; }
}
$ref =& makeReference(new Watched);
$alias =& $ref;
unset($ref);
check(Watched::$destroyed === 0);
unset($alias);
check(Watched::$destroyed === 1);
makeReference(new Watched);
check(Watched::$destroyed === 2);
echo "make reference ok\n";
?>
--EXPECT--
make reference ok
