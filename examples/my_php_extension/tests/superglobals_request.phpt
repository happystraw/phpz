--TEST--
MyPHPExt REQUEST follows request_order and remains a snapshot
--EXTENSIONS--
my_php_extension
--INI--
variables_order=GPCS
request_order=GPC
auto_globals_jit=1
--GET--
shared=get&get_only=get
--COOKIE--
shared=cookie;cookie_only=cookie
--POST--
shared=post&post_only=post
--FILE--
<?php
$before = MyPHPExt\Test\superglobalsSnapshot();

var_dump($before['GET']['shared']);
var_dump($before['POST']['shared']);
var_dump($before['COOKIE']['shared']);
var_dump($before['REQUEST']['shared']);
var_dump($before['REQUEST']['get_only']);
var_dump($before['REQUEST']['post_only']);
var_dump($before['REQUEST']['cookie_only']);

$_GET['late'] = 'late';
$after = MyPHPExt\Test\superglobalsSnapshot();
var_dump(array_key_exists('late', $after['GET']));
var_dump(array_key_exists('late', $after['REQUEST']));
?>
--EXPECT--
string(3) "get"
string(4) "post"
string(6) "cookie"
string(6) "cookie"
string(3) "get"
string(4) "post"
string(6) "cookie"
bool(false)
bool(false)
