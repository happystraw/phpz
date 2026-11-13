--TEST--
Enum case lookup validates the class and case name before asking Zend
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\enumCase;

enum Suit
{
    case Hearts;
    case Spades;
    const Wild = self::Spades;
}

class NotEnum
{
    const Hearts = 1;
}

// First access resolves the lazily evaluated case constant.
var_dump(enumCase(Suit::class, 'Hearts') === Suit::Hearts);
var_dump(enumCase(Suit::class, 'Spades') === Suit::Spades);
var_dump(enumCase(MyPHPExt\Status::class, 'Active') === MyPHPExt\Status::Active);

// Missing names, regular constants and non-enum classes are not cases.
var_dump(enumCase(Suit::class, 'Missing'));
var_dump(enumCase(Suit::class, 'Wild'));
var_dump(enumCase(Suit::class, 'hearts'));
var_dump(enumCase(NotEnum::class, 'Hearts'));
var_dump(enumCase(stdClass::class, 'Hearts'));
echo "done\n";
?>
--EXPECT--
bool(true)
bool(true)
bool(true)
NULL
NULL
NULL
NULL
NULL
done
