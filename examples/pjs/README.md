# pjs

A PHP extension that embeds [QuickJS-ng](https://github.com/mitchellh/zig-quickjs-ng) to run JavaScript from PHP.

- **Classes**: `Pjs\Runtime`, `Pjs\Context`, `Pjs\Value`, `Pjs\Exception`
- Eval JavaScript, catch JS exceptions as PHP exceptions

## Run

```bash
zig build test
```

This builds the extension and runs `test.php` against it.

Custom PHP include path:

```bash
zig build test -Dphp-include-root=/usr/include/php8.4
```

## Manually

```bash
# Build
zig build

# Run test script
php -dextension=./modules/pjs.so test.php

# Check extension info
php -dextension=./modules/pjs.so --ri pjs
```
