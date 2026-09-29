--TEST--
Stream binary I/O, line boundaries, copying, synchronization and resource ownership
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\checkStreams;
use function MyPHPExt\Test\openStream;
use function MyPHPExt\Test\readStream;
use function MyPHPExt\Test\closeStream;
use function MyPHPExt\Test\syncStream;

function check($condition) {
    if (!$condition) throw new RuntimeException('check failed');
}
checkStreams();
for ($i = 0; $i < 20; $i++) {
    $stream = openStream('php://memory');
    check(is_resource($stream) && get_resource_type($stream) === 'stream');
    fwrite($stream, "a\0b");
    rewind($stream);
    check(readStream($stream, 0) === '' && ftell($stream) === 0);
    check(readStream($stream, 20) === "a\0b" && ftell($stream) === 3);
    check(readStream($stream, 1) === '');
    rewind($stream);
    check(fread($stream, 3) === "a\0b"); // Borrowing did not close it.
    $alias = $stream;
    check(closeStream($stream) === 0);
    check(get_resource_type($stream) === 'Unknown' && get_resource_type($alias) === 'Unknown');
    try {
        readStream($alias, 1);
        throw new RuntimeException('closed stream accepted');
    } catch (TypeError $e) {}
    unset($stream, $alias);
}
try {
    readStream(stream_context_create(), 1);
    throw new RuntimeException('non-stream accepted');
} catch (TypeError $e) {}

class OwnedStream {
    public $context;
    public static int $closed = 0;
    public function stream_open($path, $mode, $options, &$openedPath) { return true; }
    public function stream_flush() { return true; }
    public function stream_close() { self::$closed++; }
}
stream_wrapper_register('streamowner', OwnedStream::class);
$stream = openStream('streamowner://test');
$alias = $stream;
unset($stream);
check(OwnedStream::$closed === 0);
unset($alias);
check(OwnedStream::$closed === 1); // toZval transferred, rather than leaked, a reference.
$stream = openStream('streamowner://test');
fclose($stream);
unset($stream);
check(OwnedStream::$closed === 2);

$path = tempnam(sys_get_temp_dir(), 'phpz-stream-');
try {
    $file = openStream($path);
    fwrite($file, 'sync');
    syncStream($file);
    fclose($file);
    check(file_get_contents($path) === 'sync');
    try {
        openStream($path . '/missing');
        throw new RuntimeException('invalid path accepted');
    } catch (Error $e) {
        check(str_contains($e->getMessage(), 'OpenFailed'));
    }
} finally {
    unlink($path);
}
// PHP owns this stream through request shutdown.
$shutdownStream = openStream('php://memory');
echo "Streams passed\n";
?>
--EXPECT--
Streams passed
