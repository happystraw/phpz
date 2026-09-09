--TEST--
MyPHPExt explicit serialization restores initialized native backing and validates saved data
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use MyPHPExt\Test\SerializableValue;

echo "native round trip\n";
foreach ([42, 0, -7] as $number) {
    $original = new SerializableValue($number);
    $restored = unserialize(serialize($original));
    var_dump($restored !== $original, $restored->value());
}

class SerializableChild extends SerializableValue {
    public string $label = 'default';
    public function __serialize(): array { return parent::__serialize() + ['label' => $this->label]; }
    public function __unserialize(array $data): void {
        parent::__unserialize($data);
        $this->label = $data['label'];
    }
}
echo "subclass protocol\n";
$original = new SerializableChild(99);
$original->label = 'saved';
$restored = unserialize(serialize($original));
var_dump($restored instanceof SerializableChild, $restored->value(), $restored->label);

echo "invalid data leaves existing backing unchanged\n";
$value = new SerializableValue(42);
foreach ([[], ['value' => 'invalid']] as $data) {
    try { $value->__unserialize($data); }
    catch (Throwable $e) { var_dump(str_contains($e->getMessage(), 'InvalidSerializedData')); }
    var_dump($value->value());
}

echo "invalid wire data\n";
$class = SerializableValue::class;
try { unserialize(sprintf('O:%d:"%s":0:{}', strlen($class), $class)); }
catch (Throwable $e) { var_dump(str_contains($e->getMessage(), 'InvalidSerializedData')); }
?>
--EXPECT--
native round trip
bool(true)
int(42)
bool(true)
int(0)
bool(true)
int(-7)
subclass protocol
bool(true)
int(99)
string(5) "saved"
invalid data leaves existing backing unchanged
bool(true)
int(42)
bool(true)
int(42)
invalid wire data
bool(true)
