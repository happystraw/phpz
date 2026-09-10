--TEST--
Zig function closures adapt Ctx, no-argument functions and error returns
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\makeFnClosure;

$example = MyPHPExt\makeSumClosure();
var_dump($example instanceof Closure, $example(20, 22));
$sum = makeFnClosure();
var_dump($sum instanceof Closure, $sum(20, 22));
$copy = clone $sum;
unset($sum);
gc_collect_cycles();
var_dump($copy(-10, 3));
try {
    $copy(1, 'invalid');
    echo "unexpected success\n";
} catch (TypeError $error) {
    echo "original TypeError preserved\n";
}
$empty = makeFnClosure('empty');
var_dump($empty());
try {
    $empty(1);
    echo "unexpected success\n";
} catch (ArgumentCountError $error) {
    echo "no-argument signature checked\n";
}
try {
    makeFnClosure('fail')();
    echo "unexpected success\n";
} catch (Error $error) {
    echo $error->getMessage(), "\n";
}
var_dump(makeFnClosure('value')());
var_dump($copy(1, 2));
?>
--EXPECT--
bool(true)
int(42)
bool(true)
int(42)
int(-7)
original TypeError preserved
NULL
no-argument signature checked
ExampleFailure at {closure}()
int(42)
int(3)
