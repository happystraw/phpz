--TEST--
BigInteger bitwise OR preserves high limbs, operand order, and assignment ownership
--FILE--
<?php
use MyPHPExt\BigInteger;
function checkValue(BigInteger $number, string $expected): void {
    if ($number->value() !== $expected) {
        throw new RuntimeException("Expected $expected, got " . $number->value());
    }
}
$cases = [
    ['1', '-18446744073709551617', '-18446744073709551617'],
    ['1', '-340282366920938463463374607431768211457', '-340282366920938463463374607431768211457'],
    ['18446744073709551615', '-680564733841876926926749214863536422913', '-680564733841876926926749214863536422913'],
    ['1', '-340282366920938463463374607431768211456', '-340282366920938463463374607431768211455'],
    ['-340282366920938463463374607431768211457', '-18446744073709551619', '-1'],
    ['340282366920938463463374607431768211457', '-3', '-3'],
    ['340282366920938463463374607431768211457', '18446744073709551618', '340282366920938463481821351505477763075'],
    ['0', '-340282366920938463463374607431768211457', '-340282366920938463463374607431768211457'],
    ['-1', '340282366920938463463374607431768211457', '-1'],
];
foreach ($cases as [$a, $b, $expected]) {
    foreach ([[$a, $b], [$b, $a]] as [$leftText, $rightText]) {
        $left = new BigInteger($leftText);
        $right = new BigInteger($rightText);
        checkValue($left | $right, $expected);
        checkValue($left, $leftText);
        checkValue($right, $rightText);
        $saved = $left;
        $alias =& $left;
        $left |= $right;
        checkValue($left, $expected);
        checkValue($alias, $expected);
        checkValue($saved, $leftText);
        checkValue($right, $rightText);
        if ($left === $saved || $left === $right || $alias !== $left) {
            throw new RuntimeException('Invalid result ownership');
        }
        unset($alias);
    }
}
$n = new BigInteger('-18446744073709551617');
checkValue(1 | $n, '-18446744073709551617');
checkValue($n | 1, '-18446744073709551617');
$n |= 1;
checkValue($n, '-18446744073709551617');
$n |= $n;
checkValue($n, '-18446744073709551617');
echo "bitwise OR passed\n";
--EXPECT--
bitwise OR passed
