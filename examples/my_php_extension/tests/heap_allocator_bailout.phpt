--TEST--
php allocator converts memory_limit bailout to OutOfMemory and runs defers
--INI--
memory_limit=8M
display_errors=0
log_errors=0
--FILE--
<?php

var_dump(MyPHPExt\testHeapAllocatorBailout());

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
