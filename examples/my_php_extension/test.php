<?php

declare(strict_types=1);

use MyPHPExt\Counter;
use MyPHPExt\Human;

echo '---------- PHP ----------', PHP_EOL;
echo 'PHP: ', PHP_VERSION, PHP_EOL;

echo '---------- Functions ----------', PHP_EOL;
hello();
echo greet('Alice'), PHP_EOL;

echo 'Create object human: ', \MyPHPExt\human("Dave"), PHP_EOL;
echo 'Create object human: ', \MyPHPExt\human("Eve", 28), PHP_EOL;
try {
    \MyPHPExt\human('Charlie', []);
    exit(1); // unreachable
} catch (\Throwable $e) {
    echo '[Error Test]: ', 'class: ', $e::class, ', error: ',  $e->getMessage(), PHP_EOL, $e->getTraceAsString(), PHP_EOL;
}

echo '---------- Methods (' . Counter::class  . ') ----------', PHP_EOL;
$obj = new Counter(10);
$obj->add(10);
$obj->dec(5);
echo 'counter: ', $obj->value(), PHP_EOL;

echo '---------- Dumper::dump(scalars) ----------', PHP_EOL;
\MyPHPExt\Dumper::dump(1, "hello", 1.1, true, false, NULL);
echo '---------- Dumper::dump(resource) ----------', PHP_EOL;
$fp = fopen('php://memory', 'r');
\MyPHPExt\Dumper::dump($fp);
fclose($fp);
echo '---------- Dumper::dump(reference) ----------', PHP_EOL;
$a = 42;
$b = &$a;
\MyPHPExt\Dumper::dump($b);
$arr = [1, 2, 3];
$ref = &$arr[0];
\MyPHPExt\Dumper::dump($arr);
echo '---------- Dumper::dump(array) ----------', PHP_EOL;
\MyPHPExt\Dumper::dump([1, 2, 3]);
echo '---------- Dumper::dump(assoc) ----------', PHP_EOL;
\MyPHPExt\Dumper::dump(["a" => 1, "b" => 2]);
echo '---------- Dumper::dump(nested) ----------', PHP_EOL;
\MyPHPExt\Dumper::dump(["a" => 1, "b" => [2, 3, "x" => [4, 5]], "c" => ["nested" => ["deep" => true, -1 => -1, -3 => new \stdClass]]]);
echo '---------- Dumper::dump(object) ----------', PHP_EOL;
\MyPHPExt\Dumper::dump(\MyPHPExt\human("Test", 25));
echo '---------- Dumper::dump(multiple args) ----------', PHP_EOL;
\MyPHPExt\Dumper::dump(42, "text", [1, 2, 3], new stdClass());
echo '---------- Dumper::dump(user class) ----------', PHP_EOL;
$user = new class {
    public string $name = 'Alice';
    public int $age = 30;
    protected string $role = 'admin';
    private string $secret = 'xyz';
};
\MyPHPExt\Dumper::dump($user);

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
