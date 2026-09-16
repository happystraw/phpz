--TEST--
bench_c_array_sum() - sums integers from array
--EXTENSIONS--
bench_c
--FILE--
<?php
var_dump(bench_c_array_sum_fast([1, 2, 3, 4, 5]));
var_dump(bench_c_array_sum_fast(range(1, 1000)));
var_dump(bench_c_array_sum_parse([1, 2, 3, 4, 5]));
var_dump(bench_c_array_sum_parse(range(1, 1000)));
?>
--EXPECT--
int(15)
int(500500)
int(15)
int(500500)
