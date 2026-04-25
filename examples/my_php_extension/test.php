<?php

declare(strict_types=1);

use MyPHPExt\Counter;
use MyPHPExt\Human;

echo '---------- PHP ----------', PHP_EOL;
echo 'PHP: ', PHP_VERSION, PHP_EOL;

echo '---------- Functions ----------', PHP_EOL;
hello();
echo greet('Alice'), PHP_EOL;

echo 'Create object human: ', human("Dave"), PHP_EOL;
echo 'Create object human: ', human("Eve", 28), PHP_EOL;
try {
    human('Charlie', []);
    exit(1); // unreachable
} catch (\Throwable $e) {
    echo '[Error Test]: ', 'class: ', $e::class, ', error: ',  $e->getMessage(), PHP_EOL, $e->getTraceAsString(), PHP_EOL;
}

echo '---------- Methods (' . Counter::class  . ') ----------', PHP_EOL;
$obj = new Counter(10);
$obj->add(10);
$obj->dec(5);
echo 'counter: ', $obj->value(), PHP_EOL;

echo '---------- Methods (' . Human::class  . ') ----------', PHP_EOL;
echo 'Humans belong to the species ', Human::species(), PHP_EOL;
$obj = new Human("Rick", 18);
echo 'getAge: ', $obj->getAge(), PHP_EOL;
echo (string)$obj, PHP_EOL;
$obj->setName('🧛‍♂️');
echo 'setAge: 1024 (out of range)', PHP_EOL;
$obj->setAge(1024);
echo 'getAge: ', $obj->getAge(), PHP_EOL;
echo (string)$obj, PHP_EOL;
