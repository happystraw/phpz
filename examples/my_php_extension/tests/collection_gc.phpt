--TEST--
MyPHPExt Collection exposes native values and subclass properties to cyclic GC
--EXTENSIONS--
my_php_extension
--FILE--
<?php
use MyPHPExt\Collection;

gc_enable();

echo "self reference\n";
$collection = new Collection();
$collection['self'] = $collection;
$weak = WeakReference::create($collection);
unset($collection);
gc_collect_cycles();
var_dump($weak->get() === null);

echo "mutual references\n";
$first = new Collection();
$second = new Collection();
$first['peer'] = $second;
$second['peer'] = $first;
$firstWeak = WeakReference::create($first);
$secondWeak = WeakReference::create($second);
unset($first, $second);
gc_collect_cycles();
var_dump($firstWeak->get() === null, $secondWeak->get() === null);

class LinkedCollection extends Collection {
    public mixed $link = null;
}

echo "native data and subclass property\n";
$first = new Collection();
$second = new LinkedCollection();
$first['peer'] = $second;
$second->link = $first;
$firstWeak = WeakReference::create($first);
$secondWeak = WeakReference::create($second);
unset($first, $second);
gc_collect_cycles();
var_dump($firstWeak->get() === null, $secondWeak->get() === null);

echo "external owner\n";
$collection = new Collection(['value' => 42]);
$collection['self'] = $collection;
$owner = $collection;
$weak = WeakReference::create($collection);
unset($collection);
gc_collect_cycles();
var_dump($weak->get() === $owner, $owner['value']);
unset($owner);
gc_collect_cycles();
var_dump($weak->get() === null);

echo "exported array\n";
$collection = new Collection();
$collection['self'] = $collection;
$exported = $collection->toArray();
$weak = WeakReference::create($collection);
unset($collection);
gc_collect_cycles();
var_dump($weak->get() === $exported['self']);
unset($exported);
gc_collect_cycles();
var_dump($weak->get() === null);

echo "independent clone cycles\n";
$collection = new Collection();
$collection['self'] = $collection;
$clone = clone $collection;
$clone['self'] = $clone;
$originalWeak = WeakReference::create($collection);
$cloneWeak = WeakReference::create($clone);
unset($collection);
gc_collect_cycles();
var_dump($originalWeak->get() === null, $cloneWeak->get() === $clone);
unset($clone);
gc_collect_cycles();
var_dump($cloneWeak->get() === null);
?>
--EXPECT--
self reference
bool(true)
mutual references
bool(true)
bool(true)
native data and subclass property
bool(true)
bool(true)
external owner
bool(true)
int(42)
bool(true)
exported array
bool(true)
bool(true)
independent clone cycles
bool(true)
bool(true)
bool(true)
