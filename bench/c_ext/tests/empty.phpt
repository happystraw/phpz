--TEST--
bench_c_empty() - returns void
--EXTENSIONS--
bench_c
--FILE--
<?php
bench_c_empty();
echo "OK\n";
?>
--EXPECT--
OK
