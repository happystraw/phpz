--TEST--
Stream argument conversion, borrowing, nullable and optional parameters
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\typedArgument as parse;
use function MyPHPExt\Test\readStream;
use function MyPHPExt\Test\nullableStream;
use function MyPHPExt\Test\optionalStream;
use function MyPHPExt\Test\optionalNullableStream;

function same($expected, $actual) {
    if ($expected !== $actual) throw new RuntimeException('Unexpected stream argument');
}
function fails(callable $call) {
    try { $call(); } catch (TypeError $e) { return; }
    throw new RuntimeException('Expected TypeError');
}
$stream = fopen('php://memory', 'w+b');
$closed = fopen('php://memory', 'w+b');
fclose($closed);
$invalid = [stream_context_create(), $closed, 1, 'stream', [], new stdClass];
foreach ([true, false] as $single) {
    foreach (['', 'nullable-', 'optional-', 'both-'] as $prefix) {
        same('stream', parse($prefix . 'stream', $single, $stream));
        foreach ($invalid as $bad) fails(fn() => parse($prefix . 'stream', $single, $bad));
    }
    same(null, parse('nullable-stream', $single, null));
    same(null, parse('both-stream', $single, null));
    same('omitted', parse('optional-stream', $single));
    same('omitted', parse('both-stream', $single));
    fails(fn() => parse('stream', $single, null));
    fails(fn() => parse('optional-stream', $single, null));
}
same('stream', nullableStream($stream));
same('null', nullableStream(null));
same('stream', optionalStream($stream));
same('omitted', optionalStream());
fails(fn() => optionalStream(null));
same('stream', optionalNullableStream($stream));
same('null', optionalNullableStream(null));
same('omitted', optionalNullableStream());
foreach ($invalid as $bad) {
    fails(fn() => readStream($bad, 1));
    fails(fn() => nullableStream($bad));
    fails(fn() => optionalStream($bad));
    fails(fn() => optionalNullableStream($bad));
}
fails(fn() => readStream(null, 1));
same(3, fwrite($stream, "a\0b"));
rewind($stream);
same("a\0b", readStream($stream, 3));
same(true, is_resource($stream));
fclose($stream);
echo "Stream arguments passed\n";
?>
--EXPECT--
Stream arguments passed
