--TEST--
Reference assignment preserves destructor writes and releases displaced values
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\createReference;
use function MyPHPExt\Test\setReference;

function check($ok) {
    if (!$ok) throw new RuntimeException('reentrant reference mismatch');
}
class Marker {
    public static int $destroyed = 0;
    public function __destruct() { ++self::$destroyed; }
}
class Reentrant {
    public static bool $throw = false;
    public function __destruct() {
        global $target, $weak;
        // A destructor may also add owners of the same reference container.
        $GLOBALS['alias'] =& $target;
        $target = new Marker;
        $weak = WeakReference::create($target);
        if (self::$throw) throw new RuntimeException('after write');
    }
}
class Box { public object|int $value; }
foreach ([false, true] as $typed) {
    foreach ([false, true] as $throw) {
        Reentrant::$throw = $throw;
        if ($typed) {
            $box = new Box;
            $box->value = new Reentrant;
            $target =& $box->value;
        } else {
            $target =& createReference('object', new Reentrant);
        }
        $before = Marker::$destroyed;
        try {
            // This replacement must be released if the destructor overwrites it.
            setReference($target, 'object', new Marker);
            check(!$throw);
        } catch (RuntimeException $e) {
            check($throw && $e->getMessage() === 'after write');
        }
        unset($e);
        check($target instanceof Marker && $alias === $target);
        check($weak->get() === $target && Marker::$destroyed === $before + 1);
        if ($typed) check($box->value === $target);
        unset($target, $alias, $box);
        check($weak->get() === null && Marker::$destroyed === $before + 2);
        unset($weak);
    }
}
echo "reentrant assignment ok\n";
?>
--EXPECT--
reentrant assignment ok
