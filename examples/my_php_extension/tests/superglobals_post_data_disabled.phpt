--TEST--
MyPHPExt POST and FILES stay empty when POST data reading is disabled
--EXTENSIONS--
my_php_extension
--INI--
variables_order=GPCS
request_order=GPC
auto_globals_jit=1
enable_post_data_reading=0
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
var_dump($snapshot['COOKIE']['cookie_only']);
var_dump(count($snapshot['POST']));
var_dump(count($snapshot['FILES']));
var_dump(array_key_exists('post_only', $snapshot['REQUEST']));
var_dump($snapshot['REQUEST']['shared']);
var_dump($snapshot['SERVER']['REQUEST_METHOD']);
?>
--EXPECT--
string(3) "get"
string(6) "cookie"
int(0)
int(0)
bool(false)
string(6) "cookie"
string(4) "POST"
