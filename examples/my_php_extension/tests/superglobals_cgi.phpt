--TEST--
MyPHPExt superglobal accessors expose CGI request data and uploads
--EXTENSIONS--
my_php_extension
--INI--
variables_order=GPCS
request_order=GPC
auto_globals_jit=1
file_uploads=1
--GET--
get_only=get&shared=get
--COOKIE--
cookie_only=cookie;shared=cookie
--POST_RAW--
Content-Type: multipart/form-data; boundary=phpz-boundary
--phpz-boundary
Content-Disposition: form-data; name="post_only"

post
--phpz-boundary
Content-Disposition: form-data; name="shared"

post
--phpz-boundary
Content-Disposition: form-data; name="upload"; filename="fixture.txt"
Content-Type: text/plain

fixture
--phpz-boundary--
--FILE--
<?php
$snapshot = MyPHPExt\Test\superglobalsSnapshot();

var_dump($snapshot['GET']['get_only']);
var_dump($snapshot['POST']['post_only']);
var_dump($snapshot['COOKIE']['cookie_only']);
var_dump($snapshot['SERVER']['REQUEST_METHOD']);
var_dump($snapshot['SERVER']['QUERY_STRING']);

$upload = $snapshot['FILES']['upload'];
var_dump($upload['name']);
var_dump($upload['full_path']);
var_dump($upload['type']);
var_dump($upload['error']);
var_dump($upload['size']);
var_dump($upload['tmp_name'] !== '');

var_dump($snapshot['REQUEST']['get_only']);
var_dump($snapshot['REQUEST']['post_only']);
var_dump($snapshot['REQUEST']['cookie_only']);
var_dump($snapshot['REQUEST']['shared']);
?>
--EXPECT--
string(3) "get"
string(4) "post"
string(6) "cookie"
string(4) "POST"
string(23) "get_only=get&shared=get"
string(11) "fixture.txt"
string(11) "fixture.txt"
string(10) "text/plain"
int(0)
int(7)
bool(true)
string(3) "get"
string(4) "post"
string(6) "cookie"
string(6) "cookie"
