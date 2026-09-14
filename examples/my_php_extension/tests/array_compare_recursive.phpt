--TEST--
Recursive array comparison preserves Zend's exception or fatal boundary
--EXTENSIONS--
my_php_extension
--INI--
display_errors=0
log_errors=0
--FILE--
<?php
// Older Zend versions raise a fatal error; newer versions throw Error.
register_shutdown_function(function () {
    $error = error_get_last();
    if ($error && $error['message'] === 'Nesting level too deep - recursive dependency?') {
        echo "Recursive comparison stopped\n";
    }
});
$a = []; $a[] = &$a;
$b = []; $b[] = &$b;
try {
    MyPHPExt\Test\compareArrays($a, $b, false, false);
    echo "unexpected success\n";
} catch (Error $error) {
    if ($error->getMessage() !== 'Nesting level too deep - recursive dependency?') throw $error;
    echo "Recursive comparison stopped\n";
}
?>
--EXPECT--
Recursive comparison stopped
