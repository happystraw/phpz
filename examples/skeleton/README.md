# Skeleton

A minimal PHP extension built with phpz.

## What's inside

- **Functions**: `hello()` prints a greeting, `greet(string $name): string` returns a personalized message
- **Class**: `Counter` has an optional initial value, `add(int $n)`, `dec(int $n)`, and `value(): int`

## Project structure

```
.
├── config.m4              # (Optional) PHP Build System Support
├── config.w32             # (Optional) PHP Build System Support
├── Makefile.frag          # (Optional) PHP Build System Support
├── php_skeleton.h         # (Optional) PHP Build System Support
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

`config.m4`, `config.w32`, `Makefile.frag`, and `php_skeleton.h` are only needed for PHP build system integration; direct `zig build` does not require them.

## Regenerate arginfo

After changing `skeleton.stub.php`, regenerate `skeleton_arginfo.h`:

```bash
php /path/to/php-src/build/gen_stub.php skeleton.stub.php
```

## Build and run

### Unix

Build and run PHPT tests:

```bash
zig build run-tests -Dphp-include-dir="$(php-config --include-dir)"
```

If `php-config` is not available, pass the PHP include root directly:

```bash
zig build run-tests -Dphp-include-dir=/usr/include/php
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
zig build run-tests `
  -Dtarget=native-native-msvc `
  -Dphp-include-dir=C:\php-sdk\include `
  -Dphp-lib-dir=C:\php-sdk\lib
```

For a thread-safe PHP SDK/runtime, add `-Dwindows-zts=true`:

```powershell
zig build run-tests `
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

## PHP build system

This optional integration primarily supports built-in extensions, while also supporting shared extensions through the standard `phpize` workflow.

[config.m4](config.m4) (Unix) and [config.w32](config.w32) (Windows) invoke `zig build` using PHP's build configuration. Zig must be in `PATH`. The default is `-Doptimize=ReleaseSafe`; set `SKELETON_ZIG_FLAGS` before configure to customize build arguments.

For a built-in extension, place this project under PHP's `ext/` directory and configure with `--enable-skeleton`.
