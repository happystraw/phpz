--TEST--
GuardCtx cleans native resources on return and errors and isolates nested scopes
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\guardResources;
use function MyPHPExt\Test\invokeArguments;
use function MyPHPExt\Test\makeFnClosure;

guardResources('normal', static function () { echo "callback\n"; });
echo "returned\n";

try {
    guardResources('zig-error', static function () {}, true);
} catch (Error $error) {
    echo $error->getMessage(), "\n";
}

try {
    guardResources('php-error', static function () { throw new RuntimeException('PHP error'); });
} catch (RuntimeException $error) {
    echo $error->getMessage(), "\n";
}

guardResources('outer', static function () {
    invokeArguments('callable', static function () {
        guardResources('inner', static function () {});
    }, [], null, false);
    echo "outer resumed\n";
});

var_dump(makeFnClosure('guard_value')());
?>
--EXPECT--
callback
defer normal
cleanup normal 2
cleanup normal 1
returned
defer zig-error
cleanup zig-error 2
cleanup zig-error 1
GuardFailure at MyPHPExt\Test\guardResources()
defer php-error
cleanup php-error 2
cleanup php-error 1
PHP error
defer inner
cleanup inner 2
cleanup inner 1
outer resumed
defer outer
cleanup outer 2
cleanup outer 1
cleanup closure 2
cleanup closure 1
int(42)
