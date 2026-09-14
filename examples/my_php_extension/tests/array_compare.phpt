--TEST--
Array compare accepts typed value callbacks and distinguishes results from PHP exceptions
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\compareArrays;

function check($condition) {
    if (!$condition) throw new RuntimeException('check failed');
}
check(compareArrays([], [], false, false) === 0);
check(compareArrays([], [1], false, false) < 0);
check(compareArrays([1], [2], false, false) < 0);
check(compareArrays([1], ['1'], false, false) === 0);
check(compareArrays([1], ['1'], false, true) !== 0);
$a = ['a' => 1, 'b' => 2];
$b = ['b' => 2, 'a' => 1];
check(compareArrays($a, $b, false, true) === 0);
check(compareArrays($a, $b, true, true) !== 0);
check(compareArrays(['a' => 1], ['z' => 1], true, false) < 0);

$value = 42;
$a = [&$value];
check(compareArrays($a, [42], true, true) === 0);

// zend_compare can return zero while this conversion warning leaves an exception.
set_error_handler(function ($type, $message) { throw new RuntimeException('comparison failed'); });
try {
    compareArrays([new stdClass], [1], false, false);
    throw new LogicException('expected comparison exception');
} catch (RuntimeException $error) {
    check($error->getMessage() === 'comparison failed');
}
restore_error_handler();
check(compareArrays([1], [1], false, false) === 0);

echo "Array comparison passed\n";
?>
--EXPECT--
Array comparison passed
