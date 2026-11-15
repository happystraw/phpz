--TEST--
exception.report() reports and consumes only the pending exception
--EXTENSIONS--
my_php_extension
--FILE--
<?php
var_dump(MyPHPExt\Test\reportPendingException());
echo "done\n";
?>
--EXPECTF--
Warning: Uncaught Exception: reported in %s:%d
Stack trace:
#0 %s
#1 {main}
  thrown in %s on line %d
bool(false)
done
