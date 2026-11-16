--TEST--
Native serialization API preserves PHP semantics and exceptions
--SKIPIF--
<?php if (!extension_loaded('my_php_extension')) die('skip'); ?>
--FILE--
<?php
use function MyPHPExt\Test\serializeValue;
use function MyPHPExt\Test\unserializeValue;

MyPHPExt\Test\checkSerializationOptions();

foreach ([null, false, true, 42, 1.25, "a\0b", [1, 'key' => false]] as $value) {
    $encoded = serializeValue($value);
    var_dump($encoded === serialize($value), unserializeValue($encoded) === $value);
}
class NativeSerialized {
    public function __serialize(): array { return ['value' => 42]; }
    public function __unserialize(array $data): void { $this->value = $data['value']; }
    public $value;
}
$encoded = serializeValue(new NativeSerialized);
var_dump(unserializeValue($encoded)->value);
var_dump(unserializeValue($encoded, ['allowed_classes' => false]) instanceof __PHP_Incomplete_Class);
var_dump(unserializeValue($encoded, ['allowed_classes' => ['nativeserialized']])->value);
var_dump(unserializeValue($encoded, ['allowed_classes' => []]) instanceof __PHP_Incomplete_Class);
var_dump(unserializeValue(serialize([[1]]), ['max_depth' => 0]) === [[1]]);
$x = 1;
$refs = [&$x, &$x];
$decoded = unserializeValue(serializeValue($refs));
$decoded[0] = 9;
var_dump($decoded[1]);
$recursive = [];
$recursive['self'] = &$recursive;
var_dump(serializeValue($recursive) === serialize($recursive));
var_dump(@unserializeValue('invalid'));
var_dump(@unserializeValue(''));
var_dump(@unserializeValue(serialize([[1]]), ['max_depth' => 1]));
class BrokenSerialize {
    public function __serialize(): array { throw new RuntimeException('serialize hook'); }
}
class BrokenUnserialize {
    public function __unserialize(array $data): void { throw new RuntimeException('unserialize hook'); }
}
foreach ([fn() => serializeValue(new BrokenSerialize),
          fn() => unserializeValue('O:17:"BrokenUnserialize":0:{}')] as $call) {
    try { $call(); } catch (Throwable $e) { echo get_class($e), "\n"; }
}
echo "alive\n";
?>
--EXPECT--
bool(true)
bool(true)
bool(true)
bool(true)
bool(true)
bool(true)
bool(true)
bool(true)
bool(true)
bool(true)
bool(true)
bool(true)
bool(true)
bool(true)
int(42)
bool(true)
int(42)
bool(true)
bool(true)
int(9)
bool(true)
bool(false)
bool(false)
bool(false)
RuntimeException
RuntimeException
alive
