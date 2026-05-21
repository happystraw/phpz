# pjs

Embed [QuickJS-ng](https://github.com/mitchellh/zig-quickjs-ng) in PHP to run JavaScript.

- `Pjs\Runtime` — JS runtime environment
- `Pjs\Context` — evaluate JS code (`$ctx->eval("1+1")`)
- `Pjs\Value` — wraps JS return values, implements `Stringable`
- `Pjs\Exception` — JS exceptions thrown as PHP exceptions

## Run

```bash
zig build test
```

Builds the extension and runs `test.php` which evals JS expressions, loads a JS file, and tests error handling.

Custom PHP include path:

```bash
zig build test -Dphp-include-dir=/usr/include/php8.4
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
