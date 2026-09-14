--TEST--
Mixed property setters borrow caller-dereferenced values and release failed writes
--EXTENSIONS--
my_php_extension
--FILE--
<?php
class Target {
    public mixed $value;
    public int $typed;
    public static mixed $shared;
    public static int $number;
}
class MagicTarget {
    function __set($name, $value) { throw new RuntimeException('magic write'); }
}
function check($condition) {
    if (!$condition) throw new RuntimeException('check failed');
}
foreach (['setMixedProperty', 'setMixedReferenceProperty'] as $method) {
    $set = 'MyPHPExt\\Test\\' . $method;
    foreach (['object', 'zval', 'static'] as $api) {
        $target = new Target;
        $name = $api === 'static' ? 'shared' : 'value';
        $value = new stdClass;
        $weak = WeakReference::create($value);
        $set($target, $name, $value, $api);
        check(($api === 'static' ? Target::$shared : $target->value) === $value);
        // Reassigning a referenced input must not change the stored property.
        $value = 'replacement';
        check($weak->get() !== null);
        $set($target, $name, $value, $api);
        check($weak->get() === null);
        check(($api === 'static' ? Target::$shared : $target->value) === 'replacement');

        $value = new stdClass;
        $weak = WeakReference::create($value);
        try {
            $set($target, $api === 'static' ? 'number' : 'typed', $value, $api);
            throw new RuntimeException('expected TypeError');
        } catch (TypeError $error) { unset($error); }
        check($weak->get() === $value);
        unset($value);
        check($weak->get() === null);

        $value = new stdClass;
        $weak = WeakReference::create($value);
        try {
            $set($api === 'static' ? $target : new MagicTarget, 'missing', $value, $api);
            throw new LogicException('expected write failure');
        } catch (RuntimeException|Error $error) { unset($error); }
        unset($value, $target);
        Target::$shared = null;
        check($weak->get() === null);
    }
}
echo "mixed property ownership passed\n";
?>
--EXPECT--
mixed property ownership passed
