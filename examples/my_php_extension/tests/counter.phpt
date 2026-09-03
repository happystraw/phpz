--TEST--
MyPHPExt Counter updates, reads, and resets its value
--FILE--
<?php

use MyPHPExt\Counter;

$counter = new Counter(10);
var_dump($counter->value());
var_dump($counter->increment());
var_dump($counter->increment(4));
var_dump($counter->decrement(3));
$counter->reset();
var_dump($counter->value());
$counter->reset(20);
var_dump($counter->value());

try {
    $counter->__construct([]);
} catch (Throwable $error) {
    echo $error::class, "\n";
}
var_dump($counter->value());

$counter->__construct(7);
var_dump($counter->value());

$uninitialized = unserialize('O:16:"MyPHPExt\\Counter":0:{}');
try {
    $uninitialized->value();
} catch (Error) {
    echo "uninitialized\n";
}
--EXPECT--
int(10)
int(11)
int(15)
int(12)
int(0)
int(20)
TypeError
int(20)
int(7)
uninitialized
