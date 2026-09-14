--TEST--
ClassEntry lookup and static reads distinguish missing values, uninitialized slots and exceptions
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\lookupClass;
use function MyPHPExt\Test\readStaticProperty;

class Target {
    public static $nil = null;
    public static int $typed;
    public static $value = 42;
}
class Deferred { public static $value = MissingDependency::VALUE; }
trait TraitTarget { public static $value = 42; }
function check($condition) {
    if (!$condition) throw new RuntimeException('check failed');
}
function throws($class, $fn) {
    try { $fn(); } catch (Throwable $error) {
        check($error instanceof $class);
        return $error;
    }
    throw new RuntimeException('expected ' . $class);
}
$loaded = [];
$failure = new RuntimeException('autoload failed');
spl_autoload_register(function ($name) use (&$loaded, $failure) {
    $loaded[] = $name;
    if ($name === 'ThrowingLoader') throw $failure;
    if ($name === 'LoadedTarget') { class LoadedTarget {} }
});
check(lookupClass('\\tArGeT', false) === Target::class);
check(lookupClass('AbsentNoLoad', false) === null && $loaded === []);
check(lookupClass('AbsentLoaded', true) === null && $loaded === ['AbsentLoaded']);
check(lookupClass('LoadedTarget', true) === 'LoadedTarget');
try {
    lookupClass('ThrowingLoader', true);
    throw new LogicException('expected autoload exception');
} catch (RuntimeException $error) { check($error === $failure); }

check(readStaticProperty(Target::class, 'nil', false) === null);
check(readStaticProperty(Target::class, 'value', false) === 42);
check(str_starts_with(throws(Error::class, fn() => readStaticProperty(Target::class, 'missing', true))->getMessage(), 'PropertyNotFound at '));
check(str_starts_with(throws(Error::class, fn() => readStaticProperty(Target::class, 'typed', true))->getMessage(), 'UninitializedProperty at '));
throws(Error::class, fn() => readStaticProperty(Target::class, 'missing', false));
throws(Error::class, fn() => readStaticProperty(Target::class, 'typed', false));
throws(Error::class, fn() => readStaticProperty(Deferred::class, 'value', true));

// Zend returns a non-null slot even when this error handler throws.
set_error_handler(function ($type, $message) { throw new ErrorException($message); });
throws(ErrorException::class, fn() => readStaticProperty(TraitTarget::class, 'value', true));
restore_error_handler();

Target::$value = new stdClass;
$weak = WeakReference::create(Target::$value);
$read = readStaticProperty(Target::class, 'value', false);
check($read === Target::$value);
Target::$value = null;
check($weak->get() === $read);
unset($read);
check($weak->get() === null);
echo "ClassEntry reads passed\n";
?>
--EXPECT--
ClassEntry reads passed
