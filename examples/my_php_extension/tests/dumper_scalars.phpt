--TEST--
Dumper::dump with scalars
--FILE--
<?php

\MyPHPExt\Dumper::dump(1, "hello", 1.1, true, false, NULL);

?>
--EXPECTF--
int(1)
string(5) "hello"
float(%f)
bool(true)
bool(false)
NULL
