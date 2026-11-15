--TEST--
.operate callbacks that skip or abandon the result leave operands intact
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use MyPHPExt\Test\FaultyOperand;

$a = new FaultyOperand;
foreach (['$a + 1', '$a - 1', '$a += 1', '$a -= 1'] as $expr) {
    try {
        eval("$expr;");
        echo "$expr: no error\n";
    } catch (Error $e) {
        echo "$expr: ", $e->getMessage(), "\n";
    }
    // Compound assignments must keep the original operand on failure.
    var_dump($a instanceof FaultyOperand);
}
unset($a);
echo "done\n";
?>
--EXPECT--
$a + 1: MyPHPExt\Test\FaultyOperand operator + did not set a result
bool(true)
$a - 1: MyPHPExt\Test\FaultyOperand operator - failed: Faulty
bool(true)
$a += 1: MyPHPExt\Test\FaultyOperand operator + did not set a result
bool(true)
$a -= 1: MyPHPExt\Test\FaultyOperand operator - failed: Faulty
bool(true)
done
