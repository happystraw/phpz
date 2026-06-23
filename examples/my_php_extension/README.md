# my_php_extension

A basic PHP extension demonstrating core phpz features:

- **Constants**: `MY_EXT_VERSION`, `MyPHPExt\VERSION`, `User::MIN_AGE`
- **Global functions**: `hello()`, `greet(string $name): string`
- **Namespaced functions**: `MyPHPExt\increment(int &$value)`, `MyPHPExt\findById(string|int $id): ?User`, `MyPHPExt\getDefaultUser(): User`, `MyPHPExt\listStatuses(): array`, `MyPHPExt\map(array $arr, callable $cb): array`
- **Interface**: `MyPHPExt\Identifiable`
- **Enums**: `MyPHPExt\Status` (int backed), `MyPHPExt\Role` (string backed)
- **Attributes**: `MyPHPExt\ExampleAttribute` and reflected attributes on `MyPHPExt\User`
- **Classes**: `MyPHPExt\User`, `MyPHPExt\Counter`, `MyPHPExt\Dumper`, `MyPHPExt\MyError`, `MyPHPExt\AbstractEntity`
- **INI directives**: `my_php_extension.greeting` (string, all), `my_php_extension.max_users` (int, system), `my_php_extension.debug` (bool, user)

## Notes

Regenerate `ExampleAttribute` arginfo with PHP 8.3+ `php-src/build/gen_stub.php`:

```bash
php /path/to/php-src/build/gen_stub.php my_php_extension.stub.php
```

This uses `php-src/Zend/zend_attributes.stub.php` to resolve
`Attribute::TARGET_*` constants. If you use a standalone copied
`build/gen_stub.php` instead, copy `php-src/Zend/zend_attributes.stub.php` to
`Zend/zend_attributes.stub.php` next to this extension first. PHP 8.2's
generator does not preserve the full `@cvalue` expression for OR'ed
`Attribute::TARGET_*` constants.

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

## Property Scratch Values

Zend property reads may return either a borrowed property zval or a temporary
value written into caller-provided scratch storage, for example when `__get`
materializes a value. Initialize the scratch zval to `undef` and destroy it only
if Zend wrote into it:

```zig
var scratch = phpz.Zval.native.undef;
const prop = try object.readProperty("name", .read, &scratch);
defer phpz.Zval.native.tryDtor(&scratch);
```

The returned `prop` pointer is borrowed unless it points at scratch. Do not dtor
the returned pointer directly.

## Manually

```bash
# Build
zig build

# Run specific PHP code with the extension loaded
php -dextension=./modules/my_php_extension.so -r 'hello();'

# Test INI directive
php -dextension=./modules/my_php_extension.so -dmy_php_extension.greeting="Hi" -r 'echo ini_get("my_php_extension.greeting");'
```
