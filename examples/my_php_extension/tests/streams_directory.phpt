--TEST--
Stream directory enumeration, borrowed name copying, rewind and closure
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\openStreamDir;
use function MyPHPExt\Test\readStreamDir;
use function MyPHPExt\Test\rewindStreamDir;

function check($condition) {
    if (!$condition) throw new RuntimeException('directory stream check failed');
}
function names($stream) {
    $result = [];
    while (($name = readStreamDir($stream)) !== null) $result[] = $name;
    sort($result);
    return $result;
}
$path = tempnam(sys_get_temp_dir(), 'phpz-directory-');
unlink($path);
mkdir($path);
file_put_contents($path . '/alpha', 'a');
file_put_contents($path . '/beta', 'b');
mkdir($path . '/child');
try {
    $stream = openStreamDir($path);
    $expected = ['.', '..', 'alpha', 'beta', 'child'];
    check(names($stream) === $expected);
    check(readStreamDir($stream) === null);
    rewindStreamDir($stream);
    check(names($stream) === $expected);
    closedir($stream);
    check(!is_resource($stream));
    try {
        readStreamDir($stream);
        throw new RuntimeException('closed directory accepted');
    } catch (TypeError $e) {}
    // Borrow directory streams created by PHP as well.
    $stream = opendir($path);
    check(names($stream) === $expected);
    closedir($stream);
    foreach ([$path . '/missing', $path . '/alpha'] as $bad) {
        try {
            // Windows PHP may emit a warning even without REPORT_ERRORS.
            @openStreamDir($bad);
            throw new RuntimeException('invalid directory accepted');
        } catch (Error $e) {
            check(str_contains($e->getMessage(), 'OpenFailed'));
        }
    }
} finally {
    if (isset($stream) && is_resource($stream)) closedir($stream);
    unlink($path . '/alpha');
    unlink($path . '/beta');
    rmdir($path . '/child');
    rmdir($path);
}
echo "Directory streams passed\n";
?>
--EXPECT--
Directory streams passed
