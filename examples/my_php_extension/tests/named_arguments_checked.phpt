--TEST--
expectArgsAllowExtraNamed validates argument slots while preserving access to extra named arguments
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\checkedNamedArguments;
use function MyPHPExt\Test\makeFnClosure;

function check($actual, $expected): void {
    if ($actual !== $expected) throw new Exception(var_export([$actual, $expected], true));
}

check(checkedNamedArguments(1), ['name' => 1, 'age' => 2]);
check(checkedNamedArguments(name: 1, extra: 3), ['name' => 1, 'age' => 2, 'extra' => 3]);
check(checkedNamedArguments(age: 4, name: 1, extra: null),
    ['name' => 1, 'age' => 4, 'extra' => null]);
check(checkedNamedArguments(...['name' => 1, 'extra' => [2, 3]]),
    ['name' => 1, 'age' => 2, 'extra' => [2, 3]]);
echo "declared names, optional defaults and named values: passed\n";

// Generic closure arginfo does not enforce required slots or their types:
// these errors must come from expectArgsAllowExtraNamed itself.
$checked = makeFnClosure('checked_named');
check($checked(1, extra: 3), ['name' => 1, 'age' => 2, 'extra' => 3]);
check($checked(1, 4, extra: 3), ['name' => 1, 'age' => 4, 'extra' => 3]);
foreach ([
    [fn () => $checked(extra: 3), ArgumentCountError::class],
    [fn () => $checked(1, 2, 3), ArgumentCountError::class],
    [fn () => $checked(1, 2, 3, extra: 4), ArgumentCountError::class],
    [fn () => checkedNamedArguments(1, 2, 3, extra: 4), ArgumentCountError::class],
    [fn () => $checked('invalid', extra: 3), TypeError::class],
    [fn () => $checked(1, 'invalid', extra: 3), TypeError::class],
] as [$call, $expected]) {
    try { $call(); throw new Exception('invalid slots accepted'); }
    catch (ArgumentCountError|TypeError $e) { check(get_class($e), $expected); }
}
check($checked(1, extra: 3), ['name' => 1, 'age' => 2, 'extra' => 3]);
echo "required slots, maximum count and type validation: passed\n";

?>
--EXPECT--
declared names, optional defaults and named values: passed
required slots, maximum count and type validation: passed
