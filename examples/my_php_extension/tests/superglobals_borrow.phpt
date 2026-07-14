--TEST--
MyPHPExt superglobal accessors expose read-only PG/EG copy-on-write boundary
--EXTENSIONS--
my_php_extension
--INI--
variables_order=EGPCS
request_order=GPC
auto_globals_jit=0
--FILE--
<?php
MyPHPExt\Test\mutateSuperglobals();

var_dump($_GET['from_zig']);
var_dump($_POST['from_zig']);
var_dump($_COOKIE['from_zig']);
var_dump($_SERVER['from_zig']);
var_dump($_ENV['from_zig']);
var_dump($_FILES['from_zig']);
var_dump($_REQUEST['from_zig']);

$_GET['from_php'] = 'get';
$_POST['from_php'] = 'post';
$_COOKIE['from_php'] = 'cookie';
$_ENV['from_php'] = 'env';
$_FILES['from_php'] = ['name' => 'files'];
$_REQUEST['from_php'] = 'request';

$snapshot = MyPHPExt\Test\superglobalsSnapshot();
var_dump(array_key_exists('from_php', $snapshot['GET']));
var_dump(array_key_exists('from_php', $snapshot['POST']));
var_dump(array_key_exists('from_php', $snapshot['COOKIE']));
var_dump(array_key_exists('from_php', $snapshot['ENV']));
var_dump(array_key_exists('from_php', $snapshot['FILES']));
var_dump($snapshot['REQUEST']['from_php']);

var_dump($_GET['from_php']);
var_dump($_POST['from_php']);
var_dump($_COOKIE['from_php']);
var_dump($_ENV['from_php']);
var_dump($_FILES['from_php']['name']);
?>
--EXPECT--
string(3) "get"
string(4) "post"
string(6) "cookie"
string(6) "server"
string(3) "env"
string(5) "files"
string(7) "request"
bool(false)
bool(false)
bool(false)
bool(false)
bool(false)
string(7) "request"
string(3) "get"
string(4) "post"
string(6) "cookie"
string(3) "env"
string(5) "files"
