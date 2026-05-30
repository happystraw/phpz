--TEST--
Counter class methods
--FILE--
<?php

$c = new Counter(10);
echo $c->value() . "\n";

$c->add(5);
echo $c->value() . "\n";

$c->add(2);
echo $c->value() . "\n";

$c->dec(3);
echo $c->value() . "\n";

$c2 = new Counter(100);
echo $c2->value() . "\n";

$c3 = new Counter();
echo $c3->value() . "\n";
--EXPECT--
10
15
17
14
100
0
