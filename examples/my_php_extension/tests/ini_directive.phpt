--TEST--
INI directive support (error_reporting)
--INI--
error_reporting=E_ALL
display_errors=stderr
--FILE--
<?php

// Trigger a notice to verify INI settings are applied
echo $undefined_var;
echo 'INI test passed', PHP_EOL;

?>
--EXPECT--
INI test passed
