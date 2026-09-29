--TEST--
Stream wrappers preserve read errors, partial writes and failure counts
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\checkStreamFailures;

class FailedStream {
    public $context;
    public function stream_open($path, $mode, $options, &$openedPath) { return true; }
    public function stream_read($count) { return false; }
    public function stream_write($data) { return false; }
    public function stream_eof() { return false; }
    public function stream_flush() { return false; }
    public function stream_seek($offset, $whence) { return false; }
    public function stream_truncate($size) { return false; }
    public function stream_close() {}
}
class ShortStream extends FailedStream {
    public static string $written = '';
    public function stream_write($data) {
        if (self::$written !== '') return 0;
        self::$written .= $data[0];
        return 1;
    }
}
stream_wrapper_register('streamfailure', FailedStream::class);
stream_wrapper_register('streamshort', ShortStream::class);
$source = fopen('streamfailure://test', 'r+b');
$destination = fopen('streamshort://test', 'w+b');
checkStreamFailures($source, $destination);
if (!is_resource($source) || !is_resource($destination) || ShortStream::$written !== 'a') {
    throw new RuntimeException('stream failure semantics changed');
}
fclose($source);
fclose($destination);
echo "Stream errors passed\n";
?>
--EXPECT--
Stream errors passed
