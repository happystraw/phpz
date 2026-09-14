--TEST--
Standard and dispatched object property handlers
--EXTENSIONS--
my_php_extension
spl
date
--FILE--
<?php
use function MyPHPExt\Test\{objectProperties, hasObjectProperty};

$object = new ArrayObject(['name' => 'Alice'], ArrayObject::ARRAY_AS_PROPS);
var_dump(hasObjectProperty($object, 'name', true));
var_dump(hasObjectProperty($object, 'name', false));

$interval = new DateInterval('P1D');
var_dump(objectProperties($interval, true));
var_dump(objectProperties($interval, false)['d']);

$object = (object) ['child' => (object) ['value' => 42]];
$properties = objectProperties($object, false);
unset($object);
var_dump($properties['child']->value);

$object = new class {
    public function __isset($name) { throw new Exception('isset failed'); }
};
foreach ([true, false] as $standard) {
    try { hasObjectProperty($object, 'missing', $standard); }
    catch (Exception $error) { echo $error->getMessage(), "\n"; }
}
?>
--EXPECT--
bool(false)
bool(true)
array(0) {
}
int(1)
int(42)
isset failed
isset failed
