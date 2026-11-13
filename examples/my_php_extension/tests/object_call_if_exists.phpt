--TEST--
callIfExists and tryCallIfExists accept a null retval and release discarded results
--EXTENSIONS--
my_php_extension
--FILE--
<?php
class Result
{
    public function __construct(private int $id) {}
    public function __destruct() { echo "released {$this->id}\n"; }
}

class Target
{
    private int $calls = 0;
    public function make(): Result
    {
        $id = ++$this->calls;
        echo "make {$id}\n";
        return new Result($id);
    }
}

MyPHPExt\Test\checkCallIfExists(new Target);
echo "done\n";
?>
--EXPECT--
make 1
released 1
make 2
released 2
make 3
released 3
done
