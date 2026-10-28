--TEST--
Stream blocking mode, read timeout and recovery on a local TCP connection
--EXTENSIONS--
my_php_extension
--SKIPIF--
<?php
foreach (['stream_socket_server', 'stream_socket_client', 'stream_socket_accept'] as $function) {
    if (!function_exists($function)) die('skip socket stream functions unavailable');
}
$server = @stream_socket_server('tcp://127.0.0.1:0', $errno, $error);
if ($server === false) die('skip loopback TCP unavailable');
fclose($server);
?>
--FILE--
<?php
use function MyPHPExt\Test\checkSocketOptions;

function check($condition) {
    if (!$condition) throw new RuntimeException('socket option check failed');
}
$server = stream_socket_server('tcp://127.0.0.1:0', $errno, $error);
check(is_resource($server));
$writer = $reader = null;
try {
    $address = stream_socket_get_name($server, false);
    $writer = stream_socket_client('tcp://' . $address, $errno, $error, 2);
    check(is_resource($writer));
    $reader = stream_socket_accept($server, 2);
    check(is_resource($reader));
    // Bound the read even if the Zig timeout setup regresses.
    check(stream_set_timeout($reader, 2));
    checkSocketOptions($reader);
    $metadata = stream_get_meta_data($reader);
    check($metadata['blocked'] && $metadata['timed_out'] && !$metadata['eof']);

    // A timeout must leave the borrowed stream usable for subsequent reads.
    check(fwrite($writer, 'x') === 1);
    check(fflush($writer));
    check(stream_set_timeout($reader, 2));
    check(fread($reader, 1) === 'x');
    check(!stream_get_meta_data($reader)['timed_out']);
} finally {
    if (is_resource($reader)) fclose($reader);
    if (is_resource($writer)) fclose($writer);
    fclose($server);
}
echo "Socket options passed\n";
?>
--EXPECT--
Socket options passed
