--TEST--
Native closures preserve captures, signatures, references and method conversion
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\makeCounter;
use function MyPHPExt\makeReference;
use function MyPHPExt\Test\wrapClosure;

function check($actual, $expected): void {
    if ($actual !== $expected) throw new Exception(var_export([$actual, $expected], true));
}
function acceptsClosure(Closure $callback): Closure { return $callback; }

$counter = acceptsClosure(makeCounter(10));
check($counter(), 11);
check($counter(step: 2), 13);
$copy = clone $counter;
check($copy(), 14);
check($counter(), 15);
$r = new ReflectionFunction($counter);
check($r->getParameters()[0]->getName(), 'step');
check($r->getParameters()[0]->getDefaultValue(), 1);
check($r->getNumberOfParameters(), 1);
check((string) $r->getReturnType(), 'int');
check($r->getClosureThis() instanceof MyPHPExt\ClosureCounter, true);
check((new ReflectionObject($counter))->getMethod('__invoke')->getParameters()[0]->getName(), 'step');
echo "native type, defaults, named arguments, reflection and shared clones: passed\n";

$value = 4;
$reference = makeReference($value);
$alias =& $reference();
$alias = 8;
check($value, 8);
$value = ['key' => 42];
check($reference(), ['key' => 42]);
check((new ReflectionFunction($reference))->returnsReference(), true);
$refCopy = clone $reference;
$other =& $refCopy();
$other = 99;
check($value, 99);
unset($alias, $other);
echo "reference capture and reference return: passed\n";

$strlen = wrapClosure('strlen');
check($strlen(string: 'hello'), 5);
try { wrapClosure('phpz_missing_function'); throw new Exception('missing function accepted'); }
catch (Error $e) { check(str_contains($e->getMessage(), 'FunctionNotFound'), true); }
$increment = wrapClosure('myphpext\\increment');
$number = 40;
$increment(value: $number, by: 2);
check($number, 42);
check((new ReflectionFunction($increment))->getParameters()[0]->isPassedByReference(), true);
$native = new MyPHPExt\Counter(20);
$method = wrapClosure('increment', $native);
$weak = WeakReference::create($native);
unset($native);
check($method(by: 3), 23);
unset($method);
check($weak->get(), null);

function sharedCounter(): int { static $n = 0; return ++$n; }
$user = wrapClosure('sharedcounter');
check($user(), 1);
check(sharedCounter(), 2);
check((clone $user)(), 3);
function closureDefaults(int $value = 1, ?int $extra = null): array { return [$value, $extra]; }
$defaults = wrapClosure('closuredefaults');
check($defaults(), [1, null]);
check($defaults(extra: 3), [1, 3]);
check((new ReflectionFunction($defaults))->getParameters()[1]->allowsNull(), true);
class ClosureBase {
    public static function who(): string { return static::class; }
    private function hidden(): string { return 'private'; }
}
class ClosureChild extends ClosureBase {}
$static = wrapClosure('who', null, ClosureChild::class);
check($static(), ClosureChild::class);
check(wrapClosure('hidden', new ClosureBase())(), 'private');
echo "internal and user functions, methods and called scope: passed\n";

foreach ([
    fn () => wrapClosure('who', new ClosureChild()),
    fn () => wrapClosure('increment', null, MyPHPExt\Counter::class),
    fn () => wrapClosure('increment', new stdClass(), MyPHPExt\Counter::class),
] as $invalid) {
    try { $invalid(); throw new Exception('invalid binding accepted'); }
    catch (Error $e) { check(str_contains($e->getMessage(), 'InvalidClosureBinding'), true); }
}
abstract class ClosureAbstract { abstract public function run(): void; }
try { wrapClosure('run', null, ClosureAbstract::class); throw new Exception('abstract accepted'); }
catch (Error $e) { check(str_contains($e->getMessage(), 'InvalidClosureFunction'), true); }
echo "invalid conversion errors: passed\n";

$owner = $r->getClosureThis();
check(is_callable($owner), true);
check($owner instanceof Closure, false);
try { serialize($owner); throw new LogicException('owner serialization accepted'); }
catch (Exception $e) { check(str_contains($e->getMessage(), 'not allowed'), true); }
try { clone $owner; throw new Exception('owner clone accepted'); }
catch (Error $e) { check(str_contains($e->getMessage(), 'uncloneable'), true); }
try { (new ReflectionMethod($owner, '__construct'))->invoke($owner); throw new Exception('constructor accepted'); }
catch (Error $e) { check(str_contains($e->getMessage(), 'Cannot directly construct'), true); }
check($counter(), 16);
echo "owner lifecycle restrictions: passed\n";
?>
--EXPECT--
native type, defaults, named arguments, reflection and shared clones: passed
reference capture and reference return: passed
internal and user functions, methods and called scope: passed
invalid conversion errors: passed
owner lifecycle restrictions: passed
