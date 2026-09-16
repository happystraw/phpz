--TEST--
bench_zig_empty() - returns void
--EXTENSIONS--
bench_zig
--FILE--
<?php
bench_zig_empty();
echo "OK\n";
?>
--EXPECT--
OK
