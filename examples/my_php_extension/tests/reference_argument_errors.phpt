--TEST--
MyPHPExt reference argument failures report types and leave aliases unchanged
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\referenceArgument;

function rejected(string $mode, string $type, bool $single, mixed $input): void {
    $value = $input;
    $alias =& $value;
    try {
        referenceArgument($mode, $type, false, $single, $value);
        echo "ERROR: invalid value accepted\n";
    } catch (TypeError $error) {
        echo $error::class, ': ', $error->getMessage(), "\n";
    }
    if ($value !== $input || $alias !== $input) {
        throw new Exception('Rejected argument was modified');
    }
}

foreach (['reference', 'zval', 'value'] as $mode) {
    echo "$mode\n";
    foreach ([false, true] as $single) {
        rejected($mode, 'int', $single, '42');
    }
}

foreach ([false, true] as $single) {
    echo $single ? "expectArg\n" : "expectArgs\n";
    foreach ([
        ['null', 0],
        ['float', 1],
        ['string', false],
        ['bool', 1],
        ['array', new stdClass()],
        ['object', []],
        ['resource', null],
        ['callable', 'not_a_real_function'],
    ] as [$type, $input]) {
        rejected('value', $type, $single, $input);
    }
    try {
        referenceArgument('value', 'int', false, $single);
        echo "ERROR: missing argument accepted\n";
    } catch (ArgumentCountError|ValueError $error) {
        echo $error::class, ': ', $error->getMessage(), "\n";
    }
}
?>
--EXPECT--
reference
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type int, string given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type int, string given
zval
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type int, string given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type int, string given
value
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type int, string given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type int, string given
expectArgs
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type null, int given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type float, int given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type string, bool given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type bool, int given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type array, object given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type object, array given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type resource, null given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type callable, string given
ArgumentCountError: MyPHPExt\Test\referenceArgument() expects exactly 5 arguments, 4 given
expectArg
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type null, int given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type float, int given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type string, bool given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type bool, int given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type array, object given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type object, array given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type resource, null given
TypeError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be of type callable, string given
ValueError: MyPHPExt\Test\referenceArgument(): Argument #5 ($value) must be provided
