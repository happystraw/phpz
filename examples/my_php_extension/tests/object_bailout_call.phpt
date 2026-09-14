--TEST--
Object tryNew captures and propagates bailout during call
--EXTENSIONS--
my_php_extension
--INI--
display_errors=0
log_errors=0
--FILE--
<?php
class NativeBoundaryTarget { public function __construct() { trigger_error("constructor bailout", E_USER_ERROR); } }
register_shutdown_function(function () { echo "PHP shutdown\n"; });
MyPHPExt\Test\checkObjectCreation('call');
echo "unexpected PHP continuation\n";
?>
--EXPECT--
caught ZendBailout
outer cleanup
PHP shutdown
