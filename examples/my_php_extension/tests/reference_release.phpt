--TEST--
Reference.release() keeps shared contents and destroys them with the last owner
--EXTENSIONS--
my_php_extension
--FILE--
<?php
class Tracked
{
    public function __destruct() { echo "destructed\n"; }
}

MyPHPExt\Test\checkReferenceRelease(Tracked::class);
echo "done\n";
?>
--EXPECT--
released shared
destructed
released last
done
