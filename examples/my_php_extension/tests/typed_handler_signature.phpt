--TEST--
Typed Zig handler parameters and returns use expectArgs and Zval.set semantics
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\makeFnClosure;

function checkTyped(mixed $actual, mixed $expected): void {
    if ($actual !== $expected) {
        throw new Exception(var_export([$actual, $expected], true));
    }
}

$narrow = makeFnClosure('narrow');
checkTyped($narrow(255), 255);
checkTyped(makeFnClosure('with_context')(41), 42);
foreach ([256, -1] as $invalid) {
    try { $narrow($invalid); throw new Exception('range accepted'); }
    catch (ValueError $error) {}
}
try { $narrow('2'); throw new Exception('string accepted'); }
catch (TypeError $error) {}
try { $narrow(1, 2); throw new Exception('extra argument accepted'); }
catch (ArgumentCountError $error) {}

$nullable = makeFnClosure('nullable_string');
checkTyped($nullable(), 'omitted');
checkTyped($nullable(null), 'null');
checkTyped($nullable('hello'), 'hello');
$callable = makeFnClosure('optional_callable');
checkTyped($callable(), 'omitted');
checkTyped($callable(null), 'null');
$called = false;
checkTyped($callable(function () use (&$called): void { $called = true; }), 'called');
checkTyped($called, true);
checkTyped(makeFnClosure('echo_bytes')("a\0b"), "a\0b");

$mixed = makeFnClosure('mixed');
foreach ([null, 42, 1.5, true, "a\0b"] as $value) {
    checkTyped($mixed($value), $value);
}
checkTyped($mixed([]), []);
try { $mixed(); throw new Exception('missing mixed argument accepted'); }
catch (ArgumentCountError $error) {}
$optionalMixed = makeFnClosure('optional_mixed');
checkTyped($optionalMixed(), 'omitted');
checkTyped($optionalMixed(null), 'null');
checkTyped($optionalMixed(42), 'int');
checkTyped($optionalMixed('hello'), 'string');
foreach ([true, 1.5, []] as $invalid) {
    try { $optionalMixed($invalid); throw new Exception('mixed type accepted'); }
    catch (TypeError $error) {}
}
$mixedArray = [random_int(1, 1000)];
$expected = $mixedArray[0];
$copy = $mixed($mixedArray);
unset($mixedArray);
checkTyped($copy, [$expected]);
$mixedObject = new stdClass();
$weak = WeakReference::create($mixedObject);
$copy = $mixed($mixedObject);
unset($mixedObject);
checkTyped($weak->get(), $copy);
unset($copy);
checkTyped($weak->get(), null);
$mixedResource = fopen('php://memory', 'w+');
$copy = $mixed($mixedResource);
unset($mixedResource);
checkTyped(fwrite($copy, 'live'), 4);
rewind($copy);
checkTyped(stream_get_contents($copy), 'live');
fclose($copy);

checkTyped(makeFnClosure('owned_string')(), 'owned');
$source = 'borrowed';
$copy = makeFnClosure('borrowed_string')($source);
unset($source);
checkTyped($copy, 'borrowed');
checkTyped(makeFnClosure('array_length')([1, 2]), 2);
checkTyped(makeFnClosure('new_array')(), []);
checkTyped(makeFnClosure('shared_array')([]), []);
$sharedSource = ['answer' => 42];
$shared = makeFnClosure('shared_array')($sharedSource);
unset($sharedSource);
checkTyped($shared, ['answer' => 42]);
$array = ['answer' => 42];
$copy = makeFnClosure('copy_mixed')($array);
unset($array);
checkTyped($copy, ['answer' => 42]);
checkTyped(makeFnClosure('maybe')(true), 42);
checkTyped(makeFnClosure('maybe')(false), null);
checkTyped(makeFnClosure('narrow_float')(1.5), 1.5);
try { makeFnClosure('narrow_float')(PHP_FLOAT_MAX); throw new Exception('f32 overflow accepted'); }
catch (ValueError $error) {}
try { makeFnClosure('too_large')(); throw new Exception('u64 overflow accepted'); }
catch (Error $error) {
    checkTyped(str_contains($error->getMessage(), 'ReturnValueOutOfRange'), true);
}

echo "typed handler signatures: passed\n";
?>
--EXPECT--
typed handler signatures: passed
