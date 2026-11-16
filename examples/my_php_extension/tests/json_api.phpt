--TEST--
JSON encoding and decoding preserve values, typed options and hook exceptions
--SKIPIF--
<?php if (!extension_loaded('my_php_extension')) die('skip'); ?>
--FILE--
<?php
use function MyPHPExt\Test\encodeJson;
use function MyPHPExt\Test\decodeJson;

function check($condition) {
    if (!$condition) throw new RuntimeException('check failed');
}
MyPHPExt\Test\checkJsonOptions();
foreach ([null, true, false, 42, 1.25, "a\0b", '/中文', [1, 'x' => false], []] as $value) {
    $encoded = encodeJson($value);
    check($encoded === json_encode($value));
    check(decodeJson($encoded, true) === $value);
}
check(decodeJson('{}') instanceof stdClass);
check(decodeJson('{}', true) === []);
check(decodeJson('null') === null);
echo "values and options OK\n";

class JsonValue implements JsonSerializable {
    public function jsonSerialize(): mixed { return ['answer' => 42]; }
}
check(encodeJson(new JsonValue) === '{"answer":42}');
class BrokenJson implements JsonSerializable {
    public function jsonSerialize(): mixed { throw new LogicException('json hook'); }
}
foreach ([false, true] as $partial) {
    try { encodeJson(new BrokenJson, $partial); throw new RuntimeException('missing exception'); }
    catch (LogicException $e) { check($e->getMessage() === 'json hook'); }
}
echo "hooks OK\n";

$recursive = [];
$recursive['self'] = &$recursive;
$resource = fopen('php://memory', 'r+');
try {
    foreach ([INF, NAN, "\xff", $recursive, $resource] as $value) {
        $failed = false;
        try { encodeJson($value); } catch (Throwable $e) { $failed = true; }
        check($failed);
        $expected = json_encode($value, JSON_PARTIAL_OUTPUT_ON_ERROR);
        $expectedError = json_last_error();
        check(encodeJson($value, true) === $expected);
        check(json_last_error() === $expectedError);
    }
} finally { fclose($resource); }
foreach (['', '{', 'null trailing', '"\\uD800"', '"' . "\xff" . '"'] as $input) {
    $failed = false;
    try { decodeJson($input); } catch (Throwable $e) { $failed = true; }
    check($failed);
}
check(decodeJson('[1,2]', true) === [1,2]);
check(encodeJson(['ok']) === '["ok"]');
echo "errors and recovery OK\n";
?>
--EXPECT--
values and options OK
hooks OK
errors and recovery OK
