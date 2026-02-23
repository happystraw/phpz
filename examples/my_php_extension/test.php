<?php

declare(strict_types=1);

use MyPHPExt\Counter;
use MyPHPExt\Human;

echo '---------- PHP ----------', PHP_EOL;
echo 'PHP: ', PHP_VERSION, PHP_EOL;

echo '---------- Functions ----------', PHP_EOL;
hello_world();
echo whoami('Alice', 25), PHP_EOL;
echo whoami('Bob', '30'), PHP_EOL;
echo whoami('Charlie'), PHP_EOL;
try {
    whoami('Charlie', []);
    exit(1); // unreachable
} catch (\Throwable $e) {
    echo 'error: ', 'class: ', $e::class, ', error: ',  $e->getMessage(), PHP_EOL, $e->getTraceAsString(), PHP_EOL;
}

echo '---------- Methods (' . Counter::class  . ') ----------', PHP_EOL;
$obj = new Counter(10);
$obj->add(10);
$obj->dec(5);
echo 'counter: ', $obj->value(), PHP_EOL;

echo '---------- Methods (' . Human::class  . ') ----------', PHP_EOL;
$obj = new Human("Rick", 18);
echo 'getAge: ', $obj->getAge(), PHP_EOL;
echo (string)$obj, PHP_EOL;
$obj->setName('🧛‍♂️');
echo 'setAge: 1024 (out of range)', PHP_EOL;
$obj->setAge(1024);
echo 'getAge: ', $obj->getAge(), PHP_EOL;
echo (string)$obj, PHP_EOL;
