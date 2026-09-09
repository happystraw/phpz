--TEST--
MyPHPExt backing replacement and destruction tolerate reentrant GC and constructors
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use MyPHPExt\Test\GcNode;

gc_enable();

class LinkedGcNode extends GcNode {
    public mixed $link = null;
}

class RunOnDestruct {
    public function __construct(private Closure $action) {}
    public function __destruct() { ($this->action)(); }
}

echo "GC during replacement\n";
$old = new stdClass();
$oldWeak = WeakReference::create($old);
$node = new LinkedGcNode($old, new RunOnDestruct(static function () use ($oldWeak) {
    gc_collect_cycles();
    var_dump($oldWeak->get() === null);
}));
$node->link = $node;
unset($old);
$new = new stdClass();
$newWeak = WeakReference::create($new);
$node->__construct($new);
unset($new);
gc_collect_cycles();
var_dump($newWeak->get() !== null);
$nodeWeak = WeakReference::create($node);
unset($node);
gc_collect_cycles();
var_dump($nodeWeak->get() === null, $newWeak->get() === null);

echo "constructor during replacement\n";
$innerWeak = null;
$node = new LinkedGcNode(null, new RunOnDestruct(static function () use (&$node, &$innerWeak) {
    $inner = new stdClass();
    $innerWeak = WeakReference::create($inner);
    $node->__construct($inner);
    gc_collect_cycles();
}));
$node->link = $node;
$outer = new stdClass();
$outerWeak = WeakReference::create($outer);
$node->__construct($outer);
unset($outer);
gc_collect_cycles();
var_dump($outerWeak->get() === null, $innerWeak->get() !== null);
$nodeWeak = WeakReference::create($node);
unset($node);
gc_collect_cycles();
var_dump($nodeWeak->get() === null, $innerWeak->get() === null);

echo "GC during destruction\n";
$old = new stdClass();
$oldWeak = WeakReference::create($old);
$node = new GcNode($old, new RunOnDestruct(static function () use ($oldWeak) {
    gc_collect_cycles();
    var_dump($oldWeak->get() === null);
}));
$nodeWeak = WeakReference::create($node);
unset($old, $node);
gc_collect_cycles();
var_dump($nodeWeak->get() === null);
?>
--EXPECT--
GC during replacement
bool(true)
bool(true)
bool(true)
bool(true)
constructor during replacement
bool(true)
bool(true)
bool(true)
bool(true)
GC during destruction
bool(true)
bool(true)
