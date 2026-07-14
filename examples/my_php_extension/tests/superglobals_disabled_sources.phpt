--TEST--
MyPHPExt disabled superglobal sources remain empty arrays
--EXTENSIONS--
my_php_extension
--INI--
variables_order=S
request_order=GPC
auto_globals_jit=1
--GET--
get_only=get
--COOKIE--
cookie_only=cookie
--POST--
post_only=post
--FILE--
<?php
$snapshot = MyPHPExt\Test\superglobalsSnapshot();

foreach (['GET', 'POST', 'COOKIE', 'ENV', 'FILES', 'REQUEST'] as $name) {
    printf("%s=%d\n", $name, count($snapshot[$name]));
}
var_dump($snapshot['SERVER']['REQUEST_METHOD']);
?>
--EXPECT--
GET=0
POST=0
COOKIE=0
ENV=0
FILES=0
REQUEST=0
string(4) "POST"
