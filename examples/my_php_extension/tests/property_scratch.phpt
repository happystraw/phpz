--TEST--
Property reads use caller-provided scratch only when Zend needs it
--FILE--
<?php

use function MyPHPExt\inspectObjectProperty;

class MagicBox
{
    public function __get(string $name): mixed
    {
        return "magic:$name";
    }
}

class TypedBox
{
    public string $name;
    public ?int $age = null;
}

$plain = (object) ['name' => 'plain'];

foreach ([
    inspectObjectProperty($plain, 'name'),
    inspectObjectProperty(new MagicBox(), 'name'),
    inspectObjectProperty(new TypedBox(), 'name', true),
    inspectObjectProperty(new TypedBox(), 'missing', true),
] as $row) {
    echo $row['kind'], '|', ($row['scratch'] ? 'scratch' : 'borrowed'), '|';
    var_export($row['value']);
    echo PHP_EOL;
}

?>
--EXPECT--
string|borrowed|'plain'
string|scratch|'magic:name'
null|borrowed|NULL
null|borrowed|NULL
