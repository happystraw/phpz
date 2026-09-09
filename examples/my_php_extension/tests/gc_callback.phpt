--TEST--
MyPHPExt gc callbacks report owned values, arrays, objects and callables
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use MyPHPExt\Test\GcNode;

gc_enable();

echo "two owned values\n";
$first = new stdClass();
$second = new stdClass();
$node = new GcNode($first, $second);
$first->node = $node;
$second->node = $node;
$nodeWeak = WeakReference::create($node);
$firstWeak = WeakReference::create($first);
$secondWeak = WeakReference::create($second);
unset($node, $first, $second);
gc_collect_cycles();
var_dump($nodeWeak->get() === null, $firstWeak->get() === null, $secondWeak->get() === null);

echo "same value owned twice\n";
$value = new stdClass();
$node = new GcNode($value, $value);
$value->node = $node;
$nodeWeak = WeakReference::create($node);
$valueWeak = WeakReference::create($value);
unset($node, $value);
gc_collect_cycles();
var_dump($nodeWeak->get() === null, $valueWeak->get() === null);

echo "external owner\n";
$value = new stdClass();
$node = new GcNode($value);
$value->node = $node;
$nodeWeak = WeakReference::create($node);
$valueWeak = WeakReference::create($value);
unset($node);
gc_collect_cycles();
var_dump($nodeWeak->get() === $value->node, $valueWeak->get() === $value);
unset($value);
gc_collect_cycles();
var_dump($nodeWeak->get() === null, $valueWeak->get() === null);

class LinkedGcNode extends GcNode {
    public mixed $link = null;
}

echo "array cycle\n";
$value = new stdClass();
$node = new GcNode(['value' => $value]);
$value->node = $node;
$nodeWeak = WeakReference::create($node);
$valueWeak = WeakReference::create($value);
unset($node, $value);
gc_collect_cycles();
var_dump($nodeWeak->get() === null, $valueWeak->get() === null);

echo "immutable array and property cycle\n";
$node = new LinkedGcNode([]);
$node->link = $node;
$weak = WeakReference::create($node);
unset($node);
gc_collect_cycles();
var_dump($weak->get() === null);

class GcCallableTarget {
    public mixed $node = null;
    public function method(): void {}
    public function __invoke(): void {}
    public function __call(string $name, array $args): void {}
    public function bound(): Closure { return function () { return $this->node; }; }
}

foreach (['closure', 'bound', 'method', 'invokable', 'magic'] as $kind) {
    echo "callable $kind\n";
    $target = new GcCallableTarget();
    $callback = match ($kind) {
        'closure' => static fn () => $target,
        'bound' => $target->bound(),
        'method' => [$target, 'method'],
        'invokable' => $target,
        'magic' => [$target, 'missing'],
    };
    $node = new GcNode(null, null, $callback);
    $target->node = $node;
    $nodeWeak = WeakReference::create($node);
    $targetWeak = WeakReference::create($target);
    unset($node, $target);
    gc_collect_cycles();
    var_dump($nodeWeak->get() !== null, $targetWeak->get() !== null);
    unset($callback);
    gc_collect_cycles();
    var_dump($nodeWeak->get() === null, $targetWeak->get() === null);
}

echo "function callable and property cycle\n";
$node = new LinkedGcNode(null, null, 'strlen');
$node->link = $node;
$weak = WeakReference::create($node);
unset($node);
gc_collect_cycles();
var_dump($weak->get() === null);

echo "null callable and property cycle\n";
$node = new LinkedGcNode(null, null, null);
$node->link = $node;
$weak = WeakReference::create($node);
unset($node);
gc_collect_cycles();
var_dump($weak->get() === null);

echo "non-refcounted values and property cycle\n";
$node = new LinkedGcNode(42, false);
$node->link = $node;
$weak = WeakReference::create($node);
unset($node);
gc_collect_cycles();
var_dump($weak->get() === null);

echo "undefined values and property cycle\n";
$node = new LinkedGcNode();
$node->link = $node;
$weak = WeakReference::create($node);
unset($node);
gc_collect_cycles();
var_dump($weak->get() === null);

echo "uninitialized backing and property cycle\n";
$node = (new ReflectionClass(LinkedGcNode::class))->newInstanceWithoutConstructor();
$node->link = $node;
$weak = WeakReference::create($node);
unset($node);
gc_collect_cycles();
var_dump($weak->get() === null);
?>
--EXPECT--
two owned values
bool(true)
bool(true)
bool(true)
same value owned twice
bool(true)
bool(true)
external owner
bool(true)
bool(true)
bool(true)
bool(true)
array cycle
bool(true)
bool(true)
immutable array and property cycle
bool(true)
callable closure
bool(true)
bool(true)
bool(true)
bool(true)
callable bound
bool(true)
bool(true)
bool(true)
bool(true)
callable method
bool(true)
bool(true)
bool(true)
bool(true)
callable invokable
bool(true)
bool(true)
bool(true)
bool(true)
callable magic
bool(true)
bool(true)
bool(true)
bool(true)
function callable and property cycle
bool(true)
null callable and property cycle
bool(true)
non-refcounted values and property cycle
bool(true)
undefined values and property cycle
bool(true)
uninitialized backing and property cycle
bool(true)
