# Skeleton

A minimal PHP extension built with phpz — the simplest possible starting point for new projects.

## What's inside

- **Functions**: `hello()` prints a greeting, `greet(string $name): string` returns a personalized message
- **Class**: `Counter` — constructor with optional initial value, `add(int $n)`, `dec(int $n)`, `value(): int`

## Project structure

```
.
├── build.zig              # Build config
├── build.zig.zon          # Dependencies
├── skeleton.h             # C header (includes phpz.h + arginfo)
├── skeleton.stub.php      # Stub file → gen_stub.php → arginfo.h
├── skeleton_arginfo.h     # Generated arginfo (do not edit)
├── run-tests.php          # PHP test runner
├── src/
│   ├── root.zig           # Entry: module setup, hello(), greet()
│   └── classes/
│       └── counter.zig    # Counter class
└── tests/
    ├── hello.phpt
    ├── greet.phpt
    └── counter.phpt
```

## Run

```bash
# Build and run tests
zig build test
```

Custom PHP include path:

```bash
zig build test -Dphp-include-dir=/usr/local/include/php
```

## Try it manually

```bash
# Build
zig build

# Run functions
php -dextension=./modules/skeleton.so -r 'hello();'
php -dextension=./modules/skeleton.so -r 'echo greet("World");'

# Use the Counter class
php -dextension=./modules/skeleton.so -r '
    $c = new Counter(5);
    $c->add(3);
    echo $c->value();
'
```

## Start your own extension

Copy this directory and rename `skeleton` to your extension name throughout:

- `build.zig.zon` → `.name`
- `build.zig` → `ext_name`
- `skeleton.h` → rename file and update `#include` guards + `phpext_*_ptr`
- `skeleton.stub.php` → rename file, update functions/classes
- `src/root.zig` → update `module(.name = ...)`

Then run `gen_stub.php` to regenerate the arginfo header and you're ready to go.
