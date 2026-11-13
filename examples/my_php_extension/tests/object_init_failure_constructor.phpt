--TEST--
Failed backing initialization skips argument evaluation and __construct
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use MyPHPExt\Test\FallibleValue;
use function MyPHPExt\Test\failNextFallible;

class ConstructedFallible extends FallibleValue
{
    public function __construct(public mixed $arg = null)
    {
        echo "constructor ran\n";
    }

    public function __destruct()
    {
        echo "destructor ran\n";
    }
}

function sideEffect(): int
{
    echo "argument evaluated\n";
    return 1;
}

failNextFallible('init');
try {
    new ConstructedFallible(sideEffect());
} catch (Error $e) {
    echo get_class($e), ": ", $e->getMessage(), "\n";
}

failNextFallible('init');
try {
    new ConstructedFallible();
} catch (Error $e) {
    echo get_class($e), ": ", $e->getMessage(), "\n";
}

failNextFallible('init');
try {
    (new ReflectionClass(ConstructedFallible::class))->newInstance(1);
} catch (Throwable $e) {
    echo get_class($e), ": ", $e->getMessage(), "\n";
    var_dump($e->getPrevious());
}

$ok = new ConstructedFallible(2);
var_dump($ok->value(), $ok->arg);
unset($ok);
echo "done\n";
?>
--EXPECT--
Error: InitRefused while initializing MyPHPExt\Test\FallibleValue
Error: InitRefused while initializing MyPHPExt\Test\FallibleValue
Error: InitRefused while initializing MyPHPExt\Test\FallibleValue
NULL
constructor ran
int(7)
int(2)
destructor ran
done
