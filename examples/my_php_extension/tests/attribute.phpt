--TEST--
PHP 8 attributes
--FILE--
<?php

use MyPHPExt\ExampleAttribute;
use MyPHPExt\User;

function dump_attribute(string $label, ReflectionAttribute $attribute): void
{
    $instance = $attribute->newInstance();
    echo $label, ': ', $instance->name, ': ', $instance->note ?? 'null', PHP_EOL;
}

$class = new ReflectionClass(User::class);
foreach ($class->getAttributes(ExampleAttribute::class) as $attribute) {
    dump_attribute('class', $attribute);
}

$method = $class->getMethod('handle');
$parameter = $method->getParameters()[0];
dump_attribute('parameter id', $parameter->getAttributes(ExampleAttribute::class)[0]);

?>
--EXPECT--
class: entity: primary user model
class: audited: null
parameter id: identifier: string or int
