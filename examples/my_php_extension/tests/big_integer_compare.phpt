--TEST--
BigInteger comparison respects value ordering, rejects uncomparable values, and preserves Zend identity rules
--FILE--
<?php
use MyPHPExt\BigInteger;
$a = new BigInteger(3); $b = new BigInteger(3); $c = new BigInteger(5);
var_dump($a == $b, $a != $b, $a <> $c, $a < $c, $a <= $b, $c > $a, $b >= $a);
var_dump($a <=> $c, $c <=> $a, $a <=> $b);
var_dump($a === $b, $a === $a, $a !== $b);
var_dump($a == 3, 3 == $a, $a < 4, 4 > $a, 2 <=> $a);
$other = new stdClass;
foreach ([fn() => $a == $other, fn() => $a != $other, fn() => $a < $other,
          fn() => $a <= $other] as $operation) {
    try { $operation(); echo "missing TypeError\n"; }
    catch (TypeError $e) { echo $e->getMessage(), "\n"; }
}
// Swapping two objects selects stdClass's handler for > and >=.
var_dump($a > $other, $a >= $other);
// Both orders reach BigInteger's handler when the other value is scalar.
foreach ([fn() => $a <=> 'bad', fn() => 'bad' <=> $a] as $operation) {
    try { $operation(); echo "missing TypeError\n"; }
    catch (TypeError $e) { echo $e->getMessage(), "\n"; }
}
var_dump($a == null, $a > null, null < $a);
var_dump([$a] == [$b], [$a] < [$c]);
class ChildBigInteger extends BigInteger {}
var_dump(new ChildBigInteger(3) == $a);
--EXPECT--
bool(true)
bool(false)
bool(true)
bool(true)
bool(true)
bool(true)
bool(true)
int(-1)
int(1)
int(0)
bool(false)
bool(true)
bool(true)
bool(true)
bool(true)
bool(true)
bool(true)
int(-1)
Cannot compare MyPHPExt\BigInteger with stdClass
Cannot compare MyPHPExt\BigInteger with stdClass
Cannot compare MyPHPExt\BigInteger with stdClass
Cannot compare MyPHPExt\BigInteger with stdClass
bool(false)
bool(false)
Cannot compare MyPHPExt\BigInteger with string
Cannot compare string with MyPHPExt\BigInteger
bool(false)
bool(true)
bool(true)
bool(true)
bool(true)
bool(true)
