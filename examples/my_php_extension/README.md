# my_php_extension

A basic PHP extension demonstrating core phpz features:

- **Functions**: `hello_world()`, `whoami()`, `human()`
- **Classes**: `MyPHPExt\Counter`, `MyPHPExt\Human`
- **Error handling**: type errors, value errors

## Run

```bash
zig build test-extension
```

This builds the extension and runs `test.php` against it.

Custom PHP include path:

```bash
zig build test-extension -Dphp-include-root=/usr/include/php8.4
```

## Manually

```bash
# Build
zig build

# Run test script
php -dextension=./modules/my_php_extension.so test.php

# Check extension info
php -dextension=./modules/my_php_extension.so --ri my_php_extension
```
