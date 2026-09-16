--TEST--
bench_zig_parse_multi() - parses 8 params including optional
--EXTENSIONS--
bench_zig
--FILE--
<?php
$obj = new stdClass();
bench_zig_parse_multi(42, 'hello', 3.14, true, [1,2,3], $obj, 'mixed');
bench_zig_parse_multi(42, 'hello', 3.14, true, [1,2,3], $obj, 'mixed', 99);
bench_zig_parse_multi_pp(42, 'hello', 3.14, true, [1,2,3], $obj, 'mixed');
bench_zig_parse_multi_pp(42, 'hello', 3.14, true, [1,2,3], $obj, 'mixed', 99);
echo "OK\n";
?>
--EXPECT--
OK
