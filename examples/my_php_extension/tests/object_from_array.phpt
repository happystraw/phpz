--TEST--
stdWithProperties and initWithProperties match the (object) array cast and borrow their input
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\objectFromArray;
use function MyPHPExt\Test\objectWithProperties;

function same(array $input): void {
    $native = objectFromArray($input);
    var_dump(get_class($native), $native == (object) $input, get_object_vars($native) === get_object_vars((object) $input));
}

same([]);                              // immutable empty array
same(['a' => 1, 'b' => [2, 3]]);       // string keys share the table
same([10, 20]);                        // packed list becomes "0", "1"
same([5 => 'x', 'k' => 'y']);          // mixed keys are converted

// The object and the source array separate on write.
$source = ['a' => 1, 'list' => [1]];
$object = objectFromArray($source);
$object->a = 2;
$object->list[] = 2;
$source['b'] = 3;
var_dump($source, get_object_vars($object));

// Integer keys are reachable as property names.
$list = objectFromArray(['zero', 'one']);
var_dump($list->{'1'});

// initWithProperties accepts classes that only hold dynamic properties.
#[AllowDynamicProperties]
class Bag {}
$input = ['name' => 'bag', 7 => 'seven'];
$bag = objectWithProperties(Bag::class, $input);
var_dump(get_class($bag), get_object_vars($bag), $input);

// Declared properties or a create_object handler would leave slots
// uninitialized or ignore the table, so the class is rejected up front.
class Declared { public int $id = 0; }
abstract class AbstractBag {}
interface BagInterface {}
foreach ([Declared::class, MyPHPExt\Counter::class, ArrayObject::class, AbstractBag::class, BagInterface::class] as $class) {
    try {
        objectWithProperties($class, ['id' => 1]);
        echo "$class: created\n";
    } catch (Error $e) {
        echo "$class: ", $e->getMessage(), "\n";
    }
}
echo "done\n";
?>
--EXPECT--
string(8) "stdClass"
bool(true)
bool(true)
string(8) "stdClass"
bool(true)
bool(true)
string(8) "stdClass"
bool(true)
bool(true)
string(8) "stdClass"
bool(true)
bool(true)
array(3) {
  ["a"]=>
  int(1)
  ["list"]=>
  array(1) {
    [0]=>
    int(1)
  }
  ["b"]=>
  int(3)
}
array(2) {
  ["a"]=>
  int(2)
  ["list"]=>
  array(2) {
    [0]=>
    int(1)
    [1]=>
    int(2)
  }
}
string(3) "one"
string(3) "Bag"
array(2) {
  ["name"]=>
  string(3) "bag"
  [7]=>
  string(5) "seven"
}
array(2) {
  ["name"]=>
  string(3) "bag"
  [7]=>
  string(5) "seven"
}
Declared: UnsupportedClass at MyPHPExt\Test\objectWithProperties()
MyPHPExt\Counter: UnsupportedClass at MyPHPExt\Test\objectWithProperties()
ArrayObject: UnsupportedClass at MyPHPExt\Test\objectWithProperties()
AbstractBag: Cannot instantiate abstract class AbstractBag
BagInterface: Cannot instantiate interface BagInterface
done
