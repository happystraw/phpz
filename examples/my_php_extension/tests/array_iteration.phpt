--TEST--
Every array iteration API matches foreach across packed, holey, mixed and reference-holding arrays
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\iterateArray;
use function MyPHPExt\Test\iterateWhileMutating;
use function MyPHPExt\Test\buildList;

function pairs(array $values): array {
    $out = [];
    foreach ($values as $key => $value) $out[] = [$key, $value];
    return $out;
}

$holes = range(0, 9);
unset($holes[0], $holes[4], $holes[9]);
$mixed = ['a' => 1, 5 => 'five', 'b' => [2], -3 => null, '10' => 1.5];
unset($mixed['b']);
$x = 'shared';
$refs = [&$x, 'k' => &$x];
$converted = [1, 2, 3];
$converted['s'] = 4;
$cases = [
    'empty' => [],
    'packed' => [1, 'two', 3.0, true, null, [1], new stdClass],
    'holes' => $holes,
    'mixed' => $mixed,
    'references' => $refs,
    'converted' => $converted,
    'large' => range(1, 2000),
];
foreach ($cases as $name => $values) {
    if (iterateArray($values) !== pairs($values)) {
        echo "$name mismatch\n";
        var_dump(iterateArray($values), pairs($values));
    }
}
// Converting to a hash at key 3 rehashes and compacts the hole left by key 1, so a
// plain HashPosition skips key 4, exactly like zend_hash_move_forward_ex().
echo json_encode(iterateWhileMutating()), "\n";

foreach ([[0, 0], [1, 0], [8, 8], [9, 8], [100, 3]] as [$count, $capacity]) {
    $object = new stdClass();
    $list = buildList($count, $capacity, $object);
    $expected = [];
    for ($i = 0; $i < $count; $i++) $expected[] = $i % 2 === 0 ? $object : $i;
    if ($list !== $expected || !array_is_list($list)) echo "list $count/$capacity mismatch\n";
    $list[] = 'next';
    if (array_key_last($list) !== $count) echo "list $count/$capacity next index wrong\n";
}
echo "done\n";
?>
--EXPECT--
[0,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,-1]
done
