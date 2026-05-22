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

Custom PHP include path:

```bash
zig build test -Dphp-include-dir=/usr/include/php8.4
```

## Tests

PHPT tests are located in `tests/`. Run with:

```bash
php run-tests.php
```

## Manually

```bash
# Build
zig build

# Run JS evaluation
php -dextension=./modules/pjs.so -r '
$rt = new Pjs\Runtime();
$ctx = new Pjs\Context($rt);
var_dump($ctx->eval("1+1"));
'
```
