--TEST--
BigInteger operators implement arithmetic, bitwise, concatenation, and value semantics
--FILE--
<?php
use MyPHPExt\BigInteger;
function show($value) { echo $value instanceof BigInteger ? "big:" . $value->value() : get_debug_type($value) . ":" . $value, "\n"; }
$a = new BigInteger(12);
$b = new BigInteger(5);
foreach ([$a + $b, $a - $b, $a * $b, $a / $b, $a % $b, $b ** 2,
          $a << 1, $a >> 2, $a & $b, $a | $b, $a ^ $b, ~$a, $a . $b,
          2 + $a, 20 - $a, +$b, -$b] as $result) show($result);
$n = new BigInteger(2);
$saved = $n;
$alias =& $n;
$n += $n;
show($n); show($alias); show($saved);
$n -= 1; show($n);
$n *= 3; show($n);
$n %= 5; show($n);
$n **= 2; show($n);
$n <<= 1; show($n);
$n >>= 2; show($n);
$n &= 6; show($n);
$n |= 1; show($n);
$n ^= 3; show($n);
$n /= 2; show($n);
$n = new BigInteger(12); $n .= new BigInteger(5); show($n);
$n = new BigInteger(5);
show($n++); show(++$n); show($n--); show(--$n); show($n);
class ChildBigInteger extends BigInteger {}
show(new ChildBigInteger(9) - 2);
foreach ([fn() => $a + '12', fn() => $a + new stdClass, fn() => $a / 0,
          fn() => $a ** -1] as $operation) {
    try { $operation(); } catch (Throwable $error) { echo $error::class, "\n"; }
}
show($a); show($b);
--EXPECT--
big:17
big:7
big:60
big:2
big:2
big:25
big:24
big:3
big:4
big:13
big:9
big:-13
string:125
big:14
big:8
big:5
big:-5
big:4
big:4
big:2
big:3
big:9
big:4
big:16
big:32
big:8
big:0
big:1
big:2
big:1
string:125
big:5
big:7
big:7
big:5
big:5
big:7
TypeError
TypeError
Error
Error
big:12
big:5
