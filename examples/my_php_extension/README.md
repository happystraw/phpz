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
- Value operators: `BigInteger` demonstrates a unified operator callback writing to a Zval result,
  three-way comparison, arbitrary-precision backing, and owned object results.
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

## Serialization

Classes with Zig backing enable serialization by binding both `__serialize`
and `__unserialize` in the current class, using automatic or explicit method
bindings. Implementing only one is a compile error. With neither hook,
serialization and unserialization are forbidden, including in PHP subclasses.
Inherited hooks do not enable serialization for a new backed class; restrictions
already set during registration are preserved. Standard-layout classes retain
Zend's normal behavior.

The hooks must save and restore the backing explicitly. PHP does not call the
constructor during unserialization. Omit `.init` with defaults for every backing
field, use `.init = .default`, or provide an initializer so backing is initialized
before `__unserialize` runs.
See [testing/serialization.zig](src/testing/serialization.zig) for a complete example.

## BigInteger

```php
$a = new MyPHPExt\BigInteger('340282366920938463463374607431768211456');
$saved = $a;
$a += 1;
echo $a->value();           // 340282366920938463463374607431768211457
echo $saved->value();       // 340282366920938463463374607431768211456
var_dump($a > $saved);      // true
$quotient = new MyPHPExt\BigInteger(-13) / 5;
echo $quotient->value();    // -2: integer division truncates toward zero
```

BigInteger uses Zig's `std.math.big.int.Managed` with PHP-managed limb storage.
The constructor accepts a PHP integer or a decimal string matching
`[+-]?[0-9]+`; `value()` and `__toString()` return the exact decimal string.
The backing owns its limbs, `.deinit` frees them, and `.clone` duplicates them.
Its small inline backing respects `ZEND_MM_ALIGNMENT`; the growing limb buffer
is separately allocated rather than limited to the object header's size.

The class registers `.operate = BigInteger.ops.operate` and an independent
`.compare = BigInteger.ops.compare`. The operator callback receives `phpz.Operator`
and `result: *phpz.Zval`, switches on the operation, writes the result with
`result.set(...)`, and returns `!void`. Unsupported inputs return `error.Unsupported`.
The opcode enum includes `bool_not` and `bool_xor`; this BigInteger example rejects
both and unnamed opcodes. PHP's ! bypasses the hook, while logical xor rarely needs overloading. The adapter owns values written into the result and releases
them on failure. The `.init` hook initializes the integer backing, so arithmetic
can create results through `Class.create()` without invoking the PHP constructor.
The adapter uses a temporary output only when the result aliases an input; other
calls write directly to Zend's output slot. BigInteger unwraps references in its
own operand reader.

Operators accept PHP integers and compatible BigInteger objects, including PHP
subclasses. Arithmetic and bitwise operations return a new base BigInteger;
concatenation returns the joined decimal strings. Numeric string operands are
rejected: construct a BigInteger explicitly. `/` truncates toward zero and `%`
retains the dividend's sign; `>>` performs arithmetic signed shifting. Exponents
must fit a nonnegative `u32`, shift counts a nonnegative `usize`; actual result
sizes are bounded by available PHP request memory, not a 64-bit integer range.
Operator helpers are separate from the backing's PHP method bindings.

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
zig build run-tests
```

Pass build options with `-D...` when the PHP installation is not in the default
location:

```sh
zig build run-tests -Dphp-include-dir=/path/to/php/include/php
zig build run-tests -Dcheck-arginfo=false
```

On Windows, use the MSVC target and pass the matching PHP SDK library directory:

```sh
zig build run-tests -Dtarget=native-windows-msvc -Dphp-include-dir=C:\path\to\php\include -Dphp-lib-dir=C:\path\to\php\lib
```

## PHP build system

The optional `config.m4`, `config.w32`, `Makefile.frag`, and `php_my_php_extension.h`
files support built-in and shared extensions through PHP's build system. They can
be deleted when using only `zig build`.

To build into PHP, place this project under PHP's `ext/` directory and configure
with `--enable-my_php_extension`. Zig must be in `PATH`. The default is
`-Doptimize=ReleaseSafe`; set `MY_PHP_EXTENSION_ZIG_FLAGS` before configure to
customize build arguments.
