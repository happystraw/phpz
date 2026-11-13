--TEST--
Exception observer ignores NULL rethrows of the pending exception
--EXTENSIONS--
my_php_extension
--FILE--
<?php
MyPHPExt\Metrics::reset();
try {
    MyPHPExt\Test\rethrowPendingException();
} catch (Exception $e) {
    echo get_class($e), ": ", $e->getMessage(), "\n";
}
$exceptions = MyPHPExt\Metrics::snapshot()['exceptions'];
var_dump($exceptions['total'], $exceptions['by_class']);
?>
--EXPECT--
Exception: rethrown
int(1)
array(1) {
  ["Exception"]=>
  int(1)
}
