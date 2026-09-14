--TEST--
mapValues transfers callback results to the output array and cleans up on exceptions
--EXTENSIONS--
my_php_extension
--FILE--
<?php
function check($condition) {
    if (!$condition) throw new RuntimeException('check failed');
}
$weak = [];
$result = MyPHPExt\mapValues(['key' => 1, 7 => 2], function ($n) use (&$weak) {
    $value = (object)['number' => $n];
    $weak[] = WeakReference::create($value);
    return $value;
});
check($weak[0]->get() === $result['key']);
check($weak[1]->get() === $result[7]);
check($result['key']->number === 1 && $result[7]->number === 2);
unset($result);
check($weak[0]->get() === null && $weak[1]->get() === null);

try {
    MyPHPExt\mapValues([1, 2], function ($n) use (&$weak) {
        if ($n === 2) throw new RuntimeException('mapper failed');
        $value = new stdClass;
        $weak[] = WeakReference::create($value);
        return $value;
    });
    throw new LogicException('expected exception');
} catch (RuntimeException $error) {
    check($error->getMessage() === 'mapper failed');
    unset($error);
}
check($weak[2]->get() === null);
echo "mapValues ownership passed\n";
?>
--EXPECT--
mapValues ownership passed
