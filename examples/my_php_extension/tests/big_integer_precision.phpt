--TEST--
BigInteger preserves arbitrary precision, signed arithmetic, cloning, and constructor state
--FILE--
<?php
declare(strict_types=1);
use MyPHPExt\BigInteger;
function show(BigInteger $n) { echo $n->value(), "\n"; }
$big = new BigInteger('340282366920938463463374607431768211456'); // 2^128
show($big + 1);
show($big * $big);
show(new BigInteger(2) ** 128);
show($big << 80);
show(($big << 80) >> 80);
show(~$big);
show(new BigInteger(-1) & $big);
show((-$big - 1) >> 128);
show(new BigInteger(-13) / 5);
show(new BigInteger(-13) % 5);
show(new BigInteger(13) / -5);
show(new BigInteger(13) % -5);
show(new BigInteger(-13) / -5);
show(new BigInteger(-13) % -5);
show(new BigInteger(-13) & 5);
show(new BigInteger(-13) | 5);
show(new BigInteger(-13) ^ 5);
show(~new BigInteger(-1));
show(~new BigInteger(0));
show(new BigInteger(0) ** 0);
show(new BigInteger(0) ** 5);
var_dump($big < $big + 1, $big <=> $big + 1, $big == new BigInteger($big->value()));
var_dump((string)$big, $big instanceof Stringable);
foreach (['+00012', '-00012', '-0000', '0000'] as $text) show(new BigInteger($text));
show(new BigInteger());
$clone = clone $big;
$big->__construct('999999999999999999999999999999999999999999999999999999');
show($clone);
try { $big->__construct('not an integer'); } catch (ValueError) { echo "invalid constructor\n"; }
show($big);
foreach (['', '+', '-', '1.2', '1e3', ' 12', '12 ', '0xff', '1_000', "12\0"] as $text) {
    try { new BigInteger($text); } catch (ValueError) { echo "invalid decimal\n"; }
}
foreach ([null, true, 1.5, [], new stdClass] as $value) {
    try { new BigInteger($value); } catch (TypeError) { echo "invalid type\n"; }
}
foreach ([fn() => $clone / 0, fn() => $clone % 0, fn() => $clone << -1,
          fn() => $clone >> -1, fn() => $clone ** -1,
          fn() => $clone ** new BigInteger('4294967296'),
          fn() => $clone << new BigInteger('18446744073709551616')] as $operation) {
    try { $operation(); } catch (Error) { echo "invalid operation\n"; }
}
// Cloning includes PHP subclass properties while duplicating the owned limbs.
class ChildBigInteger extends BigInteger { public string $tag = 'child'; }
$child = new ChildBigInteger($clone->value());
$childClone = clone $child;
$child->__construct(7);
var_dump($childClone instanceof ChildBigInteger, $childClone->tag);
show($childClone);
$old = $childClone;
$childClone += 1;
show($old);
show($childClone);
// Repeated construction, replacement, and destruction exercises owned limbs.
$before = memory_get_usage();
for ($i = 0; $i < 200; ++$i) {
    $n = new BigInteger('340282366920938463463374607431768211456');
    $copy = clone $n;
    $n *= $copy;
    $n->__construct('-999999999999999999999999999999999999999');
    unset($n, $copy);
}
var_dump(memory_get_usage() - $before < 65536);
--EXPECT--
340282366920938463463374607431768211457
115792089237316195423570985008687907853269984665640564039457584007913129639936
340282366920938463463374607431768211456
411376139330301510538742295639337626245683966408394965837152256
340282366920938463463374607431768211456
-340282366920938463463374607431768211457
340282366920938463463374607431768211456
-2
-2
-3
-2
3
2
-3
1
-9
-10
0
-1
1
0
bool(true)
int(-1)
bool(true)
string(39) "340282366920938463463374607431768211456"
bool(true)
12
-12
0
0
0
340282366920938463463374607431768211456
invalid constructor
999999999999999999999999999999999999999999999999999999
invalid decimal
invalid decimal
invalid decimal
invalid decimal
invalid decimal
invalid decimal
invalid decimal
invalid decimal
invalid decimal
invalid decimal
invalid type
invalid type
invalid type
invalid type
invalid type
invalid operation
invalid operation
invalid operation
invalid operation
invalid operation
invalid operation
invalid operation
bool(true)
string(5) "child"
340282366920938463463374607431768211456
340282366920938463463374607431768211456
340282366920938463463374607431768211457
bool(true)
