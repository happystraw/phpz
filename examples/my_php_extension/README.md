# my_php_extension

`my_php_extension` is the end-to-end showcase extension for phpz. It is not
intended to be a useful PHP package by itself; it exists to demonstrate how a
real extension is described in PHP stubs, implemented in Zig, registered with
Zend, and exercised through PHPT tests.

The public PHP API is defined by `my_php_extension.stub.php`; Zig files implement
that contract without duplicating PHP type metadata. The generated
`my_php_extension_arginfo.h` is checked in so the example follows the same stub
to arginfo workflow as a normal PHP extension.

## API groups

- Global functions: `hello()` and `greet()` cover basic exported functions,
  argument parsing, and return values.
- Namespace functions: `MyPHPExt\increment()` covers by-reference parameters;
  `MyPHPExt\mapValues()` covers arrays and callables.
- Object model: `Identifiable`, `Entity`, `User`, `Status`, `Role`, and `Tag`
  cover interfaces, abstract classes, inheritance, final methods, enums,
  attributes, typed properties, constants, constructors, and `Stringable`.
- General-purpose classes: `Counter`, `Dumper`, and `Collection` cover normal
  classes, static methods, variadic arguments, object state, `ArrayAccess`,
  `Countable`, and `Iterator`.
- Runtime configuration: `Config` exposes typed INI entries through static
  getters backed by phpz's INI helpers.
- Request telemetry: `Metrics::snapshot()` and `Metrics::reset()` demonstrate
  typed module globals plus Zend observer hooks for function calls, returns,
  errors, and exceptions.
- Test namespace: `MyPHPExt\Test\allocatorBailout()` exercises bailout-safe
  allocator behavior; `superglobalsSnapshot()` and `mutateSuperglobals()` cover
  PHP HTTP superglobal access through `PG(http_globals)` and
  `EG(symbol_table)`.

Every exported Zig handler carries a `/// PHP: ...` line matching its stub
signature. Internal helpers and observer callbacks intentionally do not.

## Runtime coverage

The example is intentionally broad so phpz changes can be validated against PHP
extension patterns that tend to break in real projects:

- Stub and arginfo generation, including namespaced functions and class entries.
- Module registration, `phpinfo()` output, and extension metadata.
- Function and method argument parsing, including optional, nullable,
  by-reference, variadic, array, object, and callable arguments.
- Zend class entries, method tables, constants, properties, interfaces,
  inheritance, attributes, and enums.
- Zval and array ownership, including returning arrays, storing mixed values,
  adding references, and copy-on-write separation before mutation.
- PHP allocator and Zend bailout paths.
- Typed module globals, request-startup reset hooks, request-local metrics,
  observer callbacks, and exception/error recording.
- HTTP superglobals in both PHP core storage and userland symbol-table storage:
  `phpz.globals.php().httpGlobal(.GET)` is a read-only request source borrow,
  while `phpz.globals.executor().superglobalMut(.GET)` prepares the userland
  `$_GET` slot for mutation.

## Metrics

`Metrics::snapshot()` returns request-local data grouped under `request`, `calls`,
`returns`, `errors`, and `exceptions`. Exception records contain copied class,
message, code, file, and line values; the observer keeps only the 16 most recent
records and reports overwritten records through `discarded`.

The metrics store is backed by `phpz.ModuleGlobals`, so it exercises phpz's
typed module-global support and per-request reset path in addition to observer
callbacks.

The fcall observer uses a fixed-depth timing stack and does not allocate. Calls to
the metrics and test APIs are excluded so observing a snapshot does not alter it.

## Testing

Run this extension's PHPT tests from this directory:

```sh
zig build test
```

Pass build options with `-D...` when the PHP installation is not in the default
location:

```sh
zig build test -Dphp-include-dir=/path/to/php/include/php
zig build test -Dcheck-arginfo=false
```

On Windows, use the MSVC target and pass the matching PHP SDK library directory:

```sh
zig build test -Dtarget=native-windows-msvc -Dphp-include-dir=C:\path\to\php\include -Dphp-lib-dir=C:\path\to\php\lib
```
