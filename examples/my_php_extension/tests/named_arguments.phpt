--TEST--
Named variadic arguments preserve keys, values, defaults and references when explicitly accepted
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\collectArguments;
use function MyPHPExt\Test\collectReferenceArguments;
use function MyPHPExt\Test\makeFnClosure;
use function MyPHPExt\Test\wrapClosure;

function check($actual, $expected): void {
    if ($actual !== $expected) throw new Exception(var_export([$actual, $expected], true));
}

check(collectArguments(), ['name' => 1, 'age' => 2]);
check(collectArguments(age: 3), ['name' => 1, 'age' => 3]);
check(collectArguments(age: 3, name: 4), ['name' => 4, 'age' => 3]);
check(collectArguments(extra: 4), ['name' => 1, 'age' => 2, 'extra' => 4]);
check(collectArguments(10, 20, 30, extra: 40, args: null),
    ['name' => 10, 'age' => 20, 0 => 30, 'extra' => 40, 'args' => null]);
check(collectArguments(...['age' => 3, 'extra' => 4]),
    ['name' => 1, 'age' => 3, 'extra' => 4]);
$converted = wrapClosure('myphpext\\test\\collectarguments');
check($converted(age: 3, extra: 4), ['name' => 1, 'age' => 3, 'extra' => 4]);

// Fixed signatures still resolve named parameters and fill skipped defaults.
check(greet(name: 'Zig'), 'Hello, Zig!');
check($converted(age: 3), ['name' => 1, 'age' => 3]);
$number = 10;
MyPHPExt\increment(by: 3, value: $number);
check($number, 13);
foreach ([fn () => hello(extra: 1), fn () => collectArguments(1, name: 2)] as $invalid) {
    try { $invalid(); throw new Exception('invalid named call accepted'); }
    catch (Error $e) { check(str_contains($e->getMessage(), 'named parameter') ||
        str_contains($e->getMessage(), 'Named parameter'), true); }
}
echo "declared names, defaults, unpacking and duplicate checks: passed\n";

$collect = makeFnClosure('named');
check($collect(), []);
check($collect(extra: 3), ['extra' => 3]);
check($collect(...[1, 'extra' => 3]), [1, 'extra' => 3]);
check($collect(args: 4), ['args' => 4]);
$held = new stdClass();
$weak = WeakReference::create($held);
$result = $collect($held, list: [1, 2], empty: null);
unset($held, $collect);
check($result, [$weak->get(), 'list' => [1, 2], 'empty' => null]);
check($weak->get() instanceof stdClass, true);
unset($result);
check($weak->get(), null);
echo "generic closure named arguments and owned result values: passed\n";

$a = 1;
$b = 2;
$result = collectReferenceArguments($a, extra: $b);
$result[0] = 10;
$result['extra'] = 20;
check([$a, $b], [10, 20]);
$b = 30;
check($result['extra'], 30);
unset($result);
$input = ['extra' => &$b];
$result = collectReferenceArguments(...$input);
$result['extra'] = 40;
check($b, 40);
echo "positional and named variadic references: passed\n";
?>
--EXPECT--
declared names, defaults, unpacking and duplicate checks: passed
generic closure named arguments and owned result values: passed
positional and named variadic references: passed
