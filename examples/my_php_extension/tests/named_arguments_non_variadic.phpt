--TEST--
Non-variadic stub functions and methods leave unknown named arguments to Zend
--EXTENSIONS--
my_php_extension
--FILE--
<?php
foreach ([
    fn () => greet(name: 'Zig', extra: 1),
    fn () => MyPHPExt\Test\typedArgument(mode: 'u8', single: true, value: 1, extra: 2),
    fn () => (new MyPHPExt\Test\FallibleValue())->value(extra: 1),
    fn () => new MyPHPExt\Test\NewValue(first: 1, extra: 2),
] as $call) {
    try {
        $call();
        echo "accepted\n";
    } catch (Error $e) {
        echo get_class($e), ': ', $e->getMessage(), "\n";
    }
}
echo greet(name: 'Zig'), "\n";
var_dump(MyPHPExt\Test\typedArgument(value: 7, single: false, mode: 'u8'));
?>
--EXPECT--
Error: Unknown named parameter $extra
Error: Unknown named parameter $extra
Error: Unknown named parameter $extra
Error: Unknown named parameter $extra
Hello, Zig!
int(7)
