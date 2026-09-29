--TEST--
Stream free preserves process exit status while keeping closed PHP resource references
--EXTENSIONS--
my_php_extension
--SKIPIF--
<?php
if (!function_exists('popen')) die('skip popen unavailable');
?>
--FILE--
<?php
use function MyPHPExt\Test\closeStream;
$stream = popen(PHP_OS_FAMILY === 'Windows' ? 'exit /b 7' : 'exit 7', 'r');
$alias = $stream;
var_dump(closeStream($stream));
var_dump(is_resource($stream), is_resource($alias));
unset($stream, $alias);
?>
--EXPECT--
int(7)
bool(false)
bool(false)
