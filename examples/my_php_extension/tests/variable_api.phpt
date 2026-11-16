--TEST--
Variable export and dump match PHP output and preserve warning exceptions
--SKIPIF--
<?php if (!extension_loaded('my_php_extension')) die('skip'); ?>
--FILE--
<?php
use function MyPHPExt\Test\exportValue;
use function MyPHPExt\Test\dumpValue;
function check($condition) {
    if (!$condition) throw new RuntimeException('check failed');
}
class DebugValue {
    public function __debugInfo(): array { return ['answer' => 42]; }
}
foreach ([null, true, 42, 1.25, "a\0b", [1, 'x' => false], new stdClass, new DebugValue] as $value) {
    check(exportValue($value) === var_export($value, true));
    ob_start();
    dumpValue($value);
    $actual = ob_get_clean();
    ob_start();
    var_dump($value);
    $expected = ob_get_clean();
    check($actual === $expected);
}
echo "export and dump OK\n";

$recursive = [];
$recursive['self'] = &$recursive;
check(@exportValue($recursive) === @var_export($recursive, true));
set_error_handler(function ($severity, $message) { throw new LogicException('export warning'); });
try {
    try { exportValue($recursive); throw new RuntimeException('missing exception'); }
    catch (LogicException $e) { check($e->getMessage() === 'export warning'); }
} finally { restore_error_handler(); }
check(exportValue(42) === '42');
echo "warning and recovery OK\n";
?>
--EXPECT--
export and dump OK
warning and recovery OK
