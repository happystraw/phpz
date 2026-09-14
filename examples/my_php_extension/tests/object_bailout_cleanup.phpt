--TEST--
Object tryNew captures and propagates bailout during cleanup
--EXTENSIONS--
my_php_extension
--INI--
display_errors=0
log_errors=0
--FILE--
<?php
class NativeBoundaryTarget {}
register_shutdown_function(function () { echo "PHP shutdown\n"; });
MyPHPExt\Test\checkObjectCreation('cleanup');
echo "unexpected PHP continuation\n";
?>
--EXPECT--
caught ZendBailout
outer cleanup
PHP shutdown
