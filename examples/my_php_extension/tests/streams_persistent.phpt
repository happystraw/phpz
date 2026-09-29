--TEST--
Persistent stream lookup, reference ownership, reuse and explicit closure
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\checkPersistentStreams;
use function MyPHPExt\Test\openPersistentStream;
use function MyPHPExt\Test\readStream;
use function MyPHPExt\Test\closeStream;
use function MyPHPExt\Test\typedArgument;

function check($condition) {
    if (!$condition) throw new RuntimeException('persistent stream check failed');
}
$path = tempnam(sys_get_temp_dir(), 'phpz-persistent-');
try {
    file_put_contents($path, "a\0bc");
    checkPersistentStreams($path);
    $stream = openPersistentStream($path);
    check(get_resource_type($stream) === 'persistent stream');
    check(readStream($stream, 2) === "a\0");
    $alias = openPersistentStream($path);
    check($stream === $alias && ftell($alias) === 2);
    foreach ([true, false] as $single) {
        check(typedArgument('stream', $single, $alias) === 'stream');
    }
    unset($stream, $alias); // Releasing request references keeps the persistent stream open.
    $stream = openPersistentStream($path);
    check(ftell($stream) === 2 && readStream($stream, 2) === 'bc');
    $alias = $stream;
    check(closeStream($stream) === 0);
    check(!is_resource($stream) && !is_resource($alias));
    $stream = openPersistentStream($path);
    check(ftell($stream) === 0 && readStream($stream, 4) === "a\0bc");
    fclose($stream);
} finally {
    if (isset($stream) && is_resource($stream)) fclose($stream);
    unlink($path);
}
echo "Persistent streams passed\n";
?>
--EXPECT--
Persistent streams passed
