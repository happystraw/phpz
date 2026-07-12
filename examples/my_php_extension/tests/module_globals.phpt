--TEST--
Module globals
--FILE--
<?php

var_dump(moduleGlobalsGet());
var_dump(moduleGlobalsIncrement());
var_dump(moduleGlobalsGet());

?>
--EXPECT--
int(42)
int(43)
int(43)
