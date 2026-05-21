# my_php_extension

A basic PHP extension demonstrating core phpz features:

- **Functions**: `hello()`, `greet(string $name): string`
- **Namespaced functions**: `MyPHPExt\human(string $name, int|null $age = null): Human`
- **Classes**: `MyPHPExt\Counter`, `MyPHPExt\Human`, `MyPHPExt\Dumper`
- **Error handling**: type errors, value errors

## Run

```bash
zig build test
```

Builds the extension and runs `test.php` which covers functions, classes, methods, and error handling.

Custom PHP include path:

```bash
zig build test -Dphp-include-dir=/usr/include/php8.4
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
