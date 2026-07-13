--TEST--
MyPHPExt Tag supports metadata and repeatable runtime attributes
--FILE--
<?php

use MyPHPExt\Tag;
use MyPHPExt\User;

$userAttributes = (new ReflectionClass(User::class))->getAttributes(Tag::class);
$userTag = $userAttributes[0]->newInstance();
var_dump($userTag->name);
var_dump($userTag->description);

#[Tag('first'), Tag('second', 'details')]
class TaggedExample {}

foreach ((new ReflectionClass(TaggedExample::class))->getAttributes(Tag::class) as $attribute) {
    $tag = $attribute->newInstance();
    var_dump([$tag->name, $tag->description]);
}
--EXPECT--
string(5) "model"
string(59) "Demonstrates properties, inheritance, enums, and attributes"
array(2) {
  [0]=>
  string(5) "first"
  [1]=>
  NULL
}
array(2) {
  [0]=>
  string(6) "second"
  [1]=>
  string(7) "details"
}
