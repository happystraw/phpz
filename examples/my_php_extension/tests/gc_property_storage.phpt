--TEST--
Backed GC preserves inline and materialized property storage and collects both kinds of cycles
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use MyPHPExt\Test\GcNode;
#[AllowDynamicProperties]
class PropertyGcNode extends GcNode {
    public mixed $link = null;
    public object $uninitialized;
    protected mixed $protectedLink = null;
    private mixed $privateLink = null;
    public function cycle(): void {
        $this->link = $this;
        $this->protectedLink = $this;
        $this->privateLink = $this;
    }
}
foreach (['inline', 'materialized', 'dynamic'] as $kind) {
    $payload = new stdClass;
    $node = new PropertyGcNode($payload, callback: static fn($v) => $v + 1);
    $node->cycle();
    $payload->node = $node;
    if ($kind === 'materialized') {
        $properties = (array) $node;
        unset($properties);
    } elseif ($kind === 'dynamic') {
        $node->dynamicLink = $node;
    }
    // The Zig method checks that get_gc leaves obj->properties unchanged.
    if ($node->invokeCallback(1) !== 2) throw new RuntimeException('callback failed');
    $weakNode = WeakReference::create($node);
    $weakPayload = WeakReference::create($payload);
    gc_collect_cycles();
    if ($weakNode->get() === null || $weakPayload->get() === null) throw new RuntimeException('live roots lost');
    unset($node, $payload);
    gc_collect_cycles();
    if ($weakNode->get() !== null || $weakPayload->get() !== null) throw new RuntimeException('cycle leaked');
    echo "$kind passed\n";
}
?>
--EXPECT--
inline passed
materialized passed
dynamic passed
