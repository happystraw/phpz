--TEST--
Zval string/str borrowing, transfers, conversions, array and property ownership
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\checkZvalStrings;
use function MyPHPExt\Test\checkStringWriteFailure;
class StringFixture {
    public string $value = '';
    public static string $shared = '';
}
foreach (['', 'x', "a\0b", "\xff\xfe", str_repeat('owned', 40)] as $text) {
    $box = new StringFixture;
    for ($i = 0; $i < 10; ++$i) {
        $result = checkZvalStrings($text, $box);
        if ($result !== $text || $box->value !== 'reset' || StringFixture::$shared !== 'reset') {
            throw new RuntimeException('String ownership or contents mismatch');
        }
    }
    unset($box, $result);
}
class RejectStringFixture {
    public int $value = 7;
    public static int $shared = 9;
}
class ThrowingStringFixture {
    public function __set($name, $value): void {
        throw new RuntimeException('rejected string');
    }
}
$typed = new RejectStringFixture;
$magic = new ThrowingStringFixture;
// Exercise both exceptions that retain argument traces and those that do not.
foreach ([0, 1] as $ignoreArgs) {
    ini_set('zend.exception_ignore_args', (string) $ignoreArgs);
    for ($i = 0; $i < 10; ++$i) {
        foreach (['object', 'zval', 'static'] as $api) {
            checkStringWriteFailure($typed, $api, TypeError::class);
        }
        foreach (['object', 'zval'] as $api) {
            checkStringWriteFailure($magic, $api, RuntimeException::class);
        }
    }
}
if ($typed->value !== 7 || RejectStringFixture::$shared !== 9) {
    throw new RuntimeException('Rejected property write modified the value');
}
echo "string ownership passed\n";
?>
--EXPECT--
string ownership passed
