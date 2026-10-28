--TEST--
Object iterator callbacks preserve PHP exceptions and release acquired iterators
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use function MyPHPExt\Test\iterateObject;
function check($ok) {
    if (!$ok) throw new RuntimeException('iterator exception mismatch');
}
class FailingIterator implements Iterator {
    public static int $destroyed = 0;
    public function __construct(private string $stage) {}
    public function __destruct() { ++self::$destroyed; }
    private function fail(string $stage): void {
        if ($this->stage === $stage) throw new RuntimeException($stage);
    }
    public function rewind(): void { $this->fail('rewind'); }
    public function valid(): bool { $this->fail('valid'); return true; }
    public function current(): mixed { $this->fail('current'); return new stdClass; }
    public function key(): mixed { $this->fail('key'); return 'key'; }
    public function next(): void { $this->fail('next'); }
}
class FailingSource implements IteratorAggregate {
    public ?WeakReference $last = null;
    public function __construct(private string $stage) {}
    public function getIterator(): Traversable {
        if ($this->stage === 'create') throw new RuntimeException('create');
        $iterator = new FailingIterator($this->stage);
        $this->last = WeakReference::create($iterator);
        return $iterator;
    }
}
foreach (['create', 'rewind', 'valid', 'current', 'key', 'next'] as $stage) {
    $before = FailingIterator::$destroyed;
    $source = new FailingSource($stage);
    try {
        iterateObject($source);
        throw new LogicException('missing exception');
    } catch (RuntimeException $e) {
        check($e->getMessage() === $stage);
    }
    unset($e);
    check($source->last === null || $source->last->get() === null);
    check(FailingIterator::$destroyed === $before + ($stage === 'create' ? 0 : 1));
}
echo "iterator exceptions ok\n";
?>
--EXPECT--
iterator exceptions ok
