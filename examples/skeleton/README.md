# Skeleton

A minimal PHP extension built with phpz.

## What's inside

- **Functions**: `hello()` prints a greeting, `greet(string $name): string` returns a personalized message
- **Class**: `Counter` has an optional initial value, `add(int $n)`, `dec(int $n)`, and `value(): int`

## Project structure

```
.
├── build.zig              # Build config
├── build.zig.zon          # Dependencies
├── skeleton.h             # C header: phpz.h + generated arginfo
├── skeleton.stub.php      # PHP API declarations
├── skeleton_arginfo.h     # Generated arginfo (do not edit directly)
├── run-tests.php          # PHP PHPT test runner
├── src/
│   └── root.zig           # Module setup, functions, and Counter class
└── tests/
    ├── hello.phpt
    ├── greet.phpt
    └── counter.phpt
```

## Regenerate arginfo

After changing `skeleton.stub.php`, regenerate `skeleton_arginfo.h`:

```bash
php /path/to/php-src/build/gen_stub.php skeleton.stub.php
```

## Build and run

### Unix

Build and run PHPT tests:

```bash
zig build test -Dphp-include-dir="$(php-config --include-dir)"
```

If `php-config` is not available, pass the PHP include root directly:

```bash
zig build test -Dphp-include-dir=/usr/include/php
```

Try it manually:

```bash
zig build -Dphp-include-dir="$(php-config --include-dir)"
php -dextension=./modules/skeleton.so -r 'hello();'
php -dextension=./modules/skeleton.so -r 'echo greet("World"), PHP_EOL;'
php -dextension=./modules/skeleton.so -r '$c = new Counter(5); $c->add(3); echo $c->value(), PHP_EOL;'
```

### Windows

Windows builds require a PHP development package from php.net matching the runtime PHP version, architecture, thread safety mode, and debug mode.

Build and run PHPT tests:

```powershell
zig build test `
  -Dtarget=native-native-msvc `
  -Dphp-include-dir=C:\php-sdk\include `
  -Dphp-lib-dir=C:\php-sdk\lib
```

For a thread-safe PHP SDK/runtime, add `-Dwindows-zts=true`:

```powershell
zig build test `
  -Dtarget=native-native-msvc `
  -Dphp-include-dir=C:\php-sdk\include `
  -Dphp-lib-dir=C:\php-sdk\lib `
  -Dwindows-zts=true
```

Try it manually:

```powershell
zig build `
  -Dtarget=native-native-msvc `
  -Dphp-include-dir=C:\php-sdk\include `
  -Dphp-lib-dir=C:\php-sdk\lib

php -dextension=.\modules\php_skeleton.dll -r "hello();"
php -dextension=.\modules\php_skeleton.dll -r 'echo greet("World"), PHP_EOL;'
php -dextension=.\modules\php_skeleton.dll -r '$c = new Counter(5); $c->add(3); echo $c->value(), PHP_EOL;'
```

Windows build options:

| Option                        | Meaning                                                                              |
| ----------------------------- | ------------------------------------------------------------------------------------ |
| `-Dtarget=native-native-msvc` | Use the MSVC ABI required by PHP for Windows extensions.                             |
| `-Dphp-include-dir=...`       | PHP SDK include root containing `main`, `Zend`, `TSRM`, and `ext`.                   |
| `-Dphp-lib-dir=...`           | PHP SDK library directory containing the matching `php8*.lib`; required on Windows.  |
| `-Dwindows-zts=true`          | Link against the thread-safe PHP library, such as `php8ts.lib`. Omit for NTS builds. |
| `-Dwindows-debug=true`        | Link against a debug PHP SDK/library. Omit for release PHP builds.                   |
| `-Dlibc-file=...`             | Optional libc paths file, mainly useful for cross-compilation.                       |
