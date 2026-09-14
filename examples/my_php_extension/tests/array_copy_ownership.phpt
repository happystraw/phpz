--TEST--
Array copy and merge retain copied values and follow Zend reference and key semantics
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\copyArray;
use function MyPHPExt\Test\mergeArray;

function check($condition) {
    if (!$condition) throw new RuntimeException('check failed');
}
foreach ([
    fn($target, $source) => copyArray($target, $source),
    fn($target, $source) => mergeArray($target, $source, true),
    fn($target, $source) => mergeArray($target, $source, false),
] as $copy) {
    // Both packed and mixed arrays must own their objects independently.
    foreach ([0, 'object'] as $key) {
        $source = [$key => new stdClass];
        $weak = WeakReference::create($source[$key]);
        $result = $copy([], $source);
        unset($source);
        check($weak->get() === $result[$key]);
        unset($result);
        check($weak->get() === null);
    }

    $value = 1;
    $source = ['ref' => &$value];
    $result = $copy([], $source);
    $result['ref'] = 2;
    check($value === 2 && $source['ref'] === 2);
    unset($result, $source, $value);

    $value = 1;
    $source = ['ref' => &$value];
    unset($value);
    $result = $copy([], $source);
    check(ReflectionReference::fromArrayElement($result, 'ref') === null);
    $result['ref'] = 2;
    check($source['ref'] === 1);
    unset($result, $source);
}

$target = [4 => 'old', 'same' => 'old', 'keep' => 1];
$source = [4 => 'new', 'same' => 'new', 9 => 'added'];
$replaced = [4 => 'new', 'same' => 'new', 'keep' => 1, 9 => 'added'];
check(copyArray($target, $source) === $replaced);
check(mergeArray($target, $source, true) === $replaced);
check(mergeArray($target, $source, false) === [4 => 'old', 'same' => 'old', 'keep' => 1, 9 => 'added']);
check($target === [4 => 'old', 'same' => 'old', 'keep' => 1]);

// A skipped source value must not gain a reference.
$source = ['same' => new stdClass];
$weak = WeakReference::create($source['same']);
$result = mergeArray(['same' => 0], $source, false);
unset($source);
check($result === ['same' => 0] && $weak->get() === null);

// Collection uses Array.copy() to retain constructor input.
$source = ['object' => new stdClass];
$weak = WeakReference::create($source['object']);
$collection = new MyPHPExt\Collection($source);
unset($source);
check($weak->get() instanceof stdClass);
unset($collection);
check($weak->get() === null);
echo "Array copying passed\n";
?>
--EXPECT--
Array copying passed
