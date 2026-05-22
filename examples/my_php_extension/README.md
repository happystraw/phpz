# my_php_extension

A basic PHP extension demonstrating core phpz features:

- **Constants**: `MY_EXT_VERSION`, `MyPHPExt\VERSION`, `User::MIN_AGE`
- **Global functions**: `hello()`, `greet(string $name): string`
- **Namespaced functions**: `MyPHPExt\increment(int &$value)`, `MyPHPExt\findById(string|int $id): ?User`, `MyPHPExt\getDefaultUser(): User`, `MyPHPExt\listStatuses(): array`
- **Interface**: `MyPHPExt\Identifiable`
- **Enums**: `MyPHPExt\Status` (int backed), `MyPHPExt\Role` (string backed)
- **Classes**: `MyPHPExt\User`, `MyPHPExt\Counter`, `MyPHPExt\Dumper`, `MyPHPExt\MyError`, `MyPHPExt\AbstractEntity`

## Run

```bash
# Build and run tests
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

# Run specific PHP code with the extension loaded
php -dextension=./modules/my_php_extension.so -r 'hello();'

# Check extension info
php -dextension=./modules/my_php_extension.so --ri my_php_extension
```
