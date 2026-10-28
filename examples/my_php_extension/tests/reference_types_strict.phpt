--TEST--
Reference assignment uses the PHP caller's strict_types setting
--EXTENSIONS--
my_php_extension
--FILE--
<?php
declare(strict_types=1);
use function MyPHPExt\Test\setReference;
class IntBox { public int $value = 7; }
$box = new IntBox;
foreach (['string', 'str', 'mixed'] as $kind) {
    try {
        setReference($box->value, $kind, '123');
        throw new RuntimeException('strict assignment accepted a string');
    } catch (TypeError $e) {
        if ($box->value !== 7) throw new RuntimeException('rejection changed value');
    }
}
setReference($box->value, 'int', 42);
var_dump($box->value);
?>
--EXPECT--
int(42)
