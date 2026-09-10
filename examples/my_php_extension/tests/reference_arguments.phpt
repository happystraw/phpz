--TEST--
MyPHPExt reference argument results preserve value slots and distinguish omitted arguments
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\referenceArgument;

function check($actual, $expected): void {
    if ($actual !== $expected) {
        throw new Exception('Unexpected result: ' . var_export([$actual, $expected], true));
    }
}

$resource = fopen('php://memory', 'r+');
$cases = [
    ['any', 41, 'int'],
    ['any', 'text', 'string'],
    ['any', null, 'null'],
    ['any', [], 'array'],
    ['any', new stdClass(), 'object'],
    ['null', null, 'null'],
    ['int', 41, 'int'],
    ['float', 1.5, 'float'],
    ['string', 'text', 'string'],
    ['bool', false, 'bool'],
    ['bool', true, 'bool'],
    ['array', ['key' => 42], 'array'],
    ['object', new stdClass(), 'object'],
    ['resource', $resource, 'resource'],
    ['callable', 'strlen', 'string'],
    ['callable', static fn () => 42, 'object'],
    ['callable', [DateTime::class, 'createFromFormat'], 'array'],
];
$types = array_unique(array_column($cases, 0));

foreach (['reference', 'zval', 'value'] as $mode) {
    foreach ([false, true] as $single) {
        foreach ([false, true] as $optional) {
            foreach ($cases as [$type, $input, $kind]) {
                $value = $input;
                $alias =& $value;
                check(referenceArgument($mode, $type, $optional, $single, $value), $kind);
                $expected = is_int($input) ? $input + 1 : $input;
                check($value, $expected);
                check($alias, $expected);
                unset($alias);
            }
        }
        foreach ($types as $type) {
            check(referenceArgument($mode, $type, true, $single), 'omitted');
        }
    }
    echo "$mode: passed\n";
}
fclose($resource);
?>
--EXPECT--
reference: passed
zval: passed
value: passed
