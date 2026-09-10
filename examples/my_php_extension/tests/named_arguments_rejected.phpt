--TEST--
Checked argument parsers reject extra named arguments before processing positional values
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\makeFnClosure;
use function MyPHPExt\Test\makeHandlerClosure;

function check($actual, $expected): void {
    if ($actual !== $expected) throw new Exception(var_export([$actual, $expected], true));
}

$sum = makeFnClosure();
$raw = makeHandlerClosure();
$empty = makeFnClosure('empty');
$fail = makeFnClosure('fail');
$parse = makeFnClosure('parse');
$variadic = makeFnClosure('parse_variadic');
foreach ([
    'expectArgs' => fn () => $sum(20, 22, extra: 1),
    'raw handler' => fn () => $raw(20, 22, extra: 1),
    'expectNoArgs' => fn () => $empty(extra: 1),
    'before target execution' => fn () => $fail(extra: 1),
    'variadic name' => fn () => $sum(args: [20, 22]),
    'unpacked named args' => fn () => $sum(...[20, 22, 'extra' => 1]),
    'parseArgs fixed' => fn () => $parse(20, 22, extra: 1),
    'parseArgs variadic' => fn () => $variadic(1, extra: 2),
    'parseArgs named only' => fn () => $variadic(extra: 2),
    'Dumper before output' => fn () => MyPHPExt\Dumper::dump(1, extra: 2),
] as $label => $invalid) {
    ob_start();
    try { $invalid(); throw new Exception('extra named argument accepted'); }
    catch (ArgumentCountError $e) {
        check(str_contains($e->getMessage(), 'does not accept unknown named parameters'), true);
    } finally {
        $output = ob_get_clean();
    }
    check($output, '');
    echo $label, ": passed\n";
}

check($sum(20, 22), 42);
check($raw(20, 22), 42);
check($empty(), null);
check($parse(20, 22), 42);
check($variadic(), 0);
check($variadic(1, 2, 3), 3);
ob_start();
MyPHPExt\Dumper::dump(123);
check(ob_get_clean(), "int(123)\n");
echo "positional calls after errors: passed\n";
?>
--EXPECT--
expectArgs: passed
raw handler: passed
expectNoArgs: passed
before target execution: passed
variadic name: passed
unpacked named args: passed
parseArgs fixed: passed
parseArgs variadic: passed
parseArgs named only: passed
Dumper before output: passed
positional calls after errors: passed
