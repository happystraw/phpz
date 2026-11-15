--TEST--
Typed, optional and manual reference-returning handlers handle temporary values
--EXTENSIONS--
my_php_extension
--FILE--
<?php
foreach (['reference', 'manual_reference'] as $kind) {
    $fn = MyPHPExt\Test\makeFnClosure($kind);
    var_dump($fn() + 1, $fn() === 42);
}
foreach (['optional_reference', 'nullable_reference'] as $kind) {
    $fn = MyPHPExt\Test\makeFnClosure($kind);
    var_dump($fn(true) + 1, $fn(false) === null);
}
?>
--EXPECT--
int(43)
bool(true)
int(43)
bool(true)
int(43)
bool(true)
int(43)
bool(true)
