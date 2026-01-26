<?php

/**
 * @generate-class-entries
 * @undocumentable
 */

namespace Pjs;

final class Runtime {}

final class Context {
    public function __construct(Runtime $runtime)
    {
    }

    public function eval(string $code): Value {}
}

final class Value implements \Stringable {
    public readonly mixed $value;
    public function __construct(Context $context, mixed $value = null)
    {
    }
    public function __toString(): string
    {
    }
}

final class Exception extends \RuntimeException {}
