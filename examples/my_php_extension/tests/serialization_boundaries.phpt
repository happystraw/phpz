--TEST--
Serialization preserves nested options, wakeup exceptions and trailing-data diagnostics
--SKIPIF--
<?php if (!extension_loaded('my_php_extension')) die('skip'); ?>
--FILE--
<?php
use function MyPHPExt\Test\unserializeValue;

function check($condition, $message) {
    if (!$condition) throw new RuntimeException($message);
}

// Autoload runs during parsing, before deferred object hooks are dispatched.
// Its nested calls exercise a shared unserialization context.
$autoloaded = false;
$loader = function ($name) use (&$autoloaded) {
    if ($name !== 'NestedLoaded') return;
    $autoloaded = true;
    check(unserializeValue('O:8:"stdClass":0:{}') instanceof stdClass, 'nested all classes');
    check(@unserializeValue(serialize([[1]]), ['max_depth' => 1]) === false, 'nested depth limit');
    class NestedLoaded {}
};
spl_autoload_register($loader);
try {
    $value = unserializeValue(
        'a:3:{i:0;O:12:"NestedLoaded":0:{}i:1;O:8:"stdClass":0:{}i:2;a:1:{i:0;a:1:{i:0;i:1;}}}',
        ['allowed_classes' => ['NestedLoaded'], 'max_depth' => 3]
    );
    check($autoloaded && $value[0] instanceof NestedLoaded, 'outer autoload');
    check($value[1] instanceof __PHP_Incomplete_Class, 'outer class restriction restored');
    check($value[2] === [[1]], 'outer depth restored');
} finally {
    spl_autoload_unregister($loader);
}
echo "nested options restored\n";

class BrokenWakeup {
    public function __wakeup(): void { throw new RuntimeException('wakeup failed'); }
}
try {
    unserializeValue('O:12:"BrokenWakeup":0:{}');
    throw new LogicException('missing wakeup exception');
} catch (RuntimeException $e) {
    check($e->getMessage() === 'wakeup failed', 'exception preserved');
}
check(unserializeValue('i:42;') === 42, 'usable after wakeup exception');
echo "wakeup exception preserved\n";

$warnings = [];
set_error_handler(function ($severity, $message) use (&$warnings) {
    $warnings[] = [$severity, $message];
    return true;
});
try {
    check(unserializeValue('i:42;extra') === 42, 'trailing data result');
} finally {
    restore_error_handler();
}
if (PHP_VERSION_ID >= 80300) {
    check(count($warnings) === 1, 'one trailing data warning');
    check($warnings[0][0] === E_WARNING, 'warning severity');
    check(str_contains($warnings[0][1], 'Extra data starting at offset 5 of 10 bytes'), 'warning offset');
} else {
    check($warnings === [], 'PHP 8.2 allows trailing data silently');
}
echo "trailing data matches PHP\n";
?>
--EXPECT--
nested options restored
wakeup exception preserved
trailing data matches PHP
