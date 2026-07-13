--TEST--
my_php_extension allocator bailout preserves Zig cleanup
--EXTENSIONS--
my_php_extension
--INI--
memory_limit=16M
display_errors=0
log_errors=0
--FILE--
<?php
var_dump(MyPHPExt\Test\allocatorBailout());
?>
--EXPECT--
array(4) {
  ["out_of_memory"]=>
  bool(true)
  ["scope_defer"]=>
  bool(true)
  ["cleanup_defer"]=>
  bool(true)
  ["freed_blocks"]=>
  bool(true)
}
