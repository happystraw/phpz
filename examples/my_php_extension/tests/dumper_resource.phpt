--TEST--
Dumper::dump with resource
--FILE--
<?php

$fp = fopen('php://memory', 'r');
\MyPHPExt\Dumper::dump($fp);
fclose($fp);

?>
--EXPECTF--
resource(%d)
