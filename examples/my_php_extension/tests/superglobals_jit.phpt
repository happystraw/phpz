--TEST--
MyPHPExt superglobal accessors initialize JIT globals
--EXTENSIONS--
my_php_extension
--INI--
variables_order=EGPCS
request_order=GPC
auto_globals_jit=1
register_argc_argv=0
--ENV--
PHPZ_SUPERGLOBALS_ENV=environment
--FILE--
<?php
$snapshot = MyPHPExt\Test\superglobalsSnapshot();

foreach (['GET', 'POST', 'COOKIE', 'SERVER', 'ENV', 'FILES', 'REQUEST'] as $name) {
    printf("%s=%s\n", $name, get_debug_type($snapshot[$name]));
}

var_dump($snapshot['ENV']['PHPZ_SUPERGLOBALS_ENV']);
var_dump($snapshot['SERVER']['PHPZ_SUPERGLOBALS_ENV']);
?>
--EXPECT--
GET=array
POST=array
COOKIE=array
SERVER=array
ENV=array
FILES=array
REQUEST=array
string(11) "environment"
string(11) "environment"
