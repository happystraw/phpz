--TEST--
Typed resources register distinct types, validate access, and destroy payloads once
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\{createResource, readResource, closeResource, resourceDestructions};
use function MyPHPExt\Test\{resourceTypeName, checkResourceRelease};

function check($ok) {
    if (!$ok) throw new RuntimeException('typed resource mismatch');
}
$before = resourceDestructions();
$value = createResource(42, false);
$other = createResource(7, true);
check(get_resource_type($value) === 'phpz-value');
check(get_resource_type($other) === 'phpz-other');
check(resourceTypeName($value) === 'phpz-value' && resourceTypeName($other) === 'phpz-other');
check(readResource($value, false) === 42 && readResource($other, true) === 7);

$stream = fopen('php://memory', 'w+');
check(resourceTypeName($stream) === 'stream');
foreach ([$other, $stream] as $wrong) {
    try {
        readResource($wrong, false);
        throw new RuntimeException('wrong resource type accepted');
    } catch (TypeError $e) {
        check(str_contains($e->getMessage(), 'phpz-value'));
    }
}
unset($wrong, $e);
fclose($stream);

$alias = $value;
unset($value);
check(resourceDestructions() === $before && readResource($alias, false) === 42);
closeResource($alias);
check(resourceDestructions() === $before + 1 && !is_resource($alias));
check(resourceTypeName($alias) === null);
try {
    readResource($alias, false);
    throw new RuntimeException('closed resource accepted');
} catch (TypeError $e) {
    check(str_contains($e->getMessage(), 'phpz-value'));
}
unset($e);
closeResource($alias);
unset($alias);
check(resourceDestructions() === $before + 1);
unset($other);
check(resourceDestructions() === $before + 2);
createResource(99, false);
check(resourceDestructions() === $before + 3);
check(checkResourceRelease());
echo "typed resources ok\n";
?>
--EXPECT--
typed resources ok
