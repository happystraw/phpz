# Phpz - Build PHP Extensions with Zig

A Zig framework for building PHP extensions with PHP C API bindings.

> **ℹ️ Note**: This is a personal experimental project — functionality works well for its intended use cases, but expect API changes as it evolves. Pin to a specific commit if you need stability.

## Requirements

- zig: 0.16.0
- php: 8.2-8.5 tested on linux/macos

## Features

- **Module Lifecycle** — `module_startup`, `module_shutdown`, `request_startup`, `request_shutdown`, `info` (`phpinfo()`)
- **Function Registration** — `phpz.function()` with type-safe parameter parsing (optional, nullable, typed specifiers)
- **Class & OOP** — `phpz.Class` (struct with `init`/`deinit`), `phpz.SimpleClass` (interfaces, enums, exceptions), static/instance methods, properties, inheritance
- **Type-safe Zval** — checked type conversions, `Zval.Array` / `Zval.Object` builders
- **Zend APIs** — `zend.Array` (HashTable), `zend.String`, `zend.Object`, `zend.Function`, `zend.ClassEntry`, `zend.Property`, `zend.Callable`
- **INI Settings** — `php.ini` directives with on-update callbacks (`string`, `long`, `double`, `bool`)
- **Error Handling** — PHP error triggers, argument errors, exception throwing
- **PHP Memory Allocator** — `heap.php_allocator` wrapping `emalloc` as a Zig `Allocator`

## Usage

> **💡 Tip**: For complete working examples, see the [`examples/`](./examples/) directory.

### 1. Add Phpz

Add `phpz` to your `build.zig.zon`

```bash
zig fetch --save git+https://github.com/happystraw/phpz
```

### 2. Generate arginfo.h (Recommended)

For PHP 8.0+, it's recommended to use stub files to generate arginfo headers:

Create a stub file (e.g., `my_php_extension.stub.php`):

```php
<?php

/**
 * @generate-class-entries
 * @undocumentable
 */

function hello_world(): void {}

function my_function(string $name, int $age = 0): string {}
```

Generate the arginfo header using PHP's gen_stub.php:

```bash
php /path/to/php-src/build/gen_stub.php my_php_extension.stub.php
```

This will generate `my_php_extension_arginfo.h` containing all the necessary argument info definitions.

### 3. Configure build.zig

Create a C header file (e.g., `my_php_extension.h`):

> [phpz.h](./build/phpz.h) provides the core C API needed for building PHP extensions (includes `php.h` and `Zend/zend_API.h`).
>
> Include it in your extension header to access all necessary PHP C APIs.

```c
#include "phpz.h"
#include "my_php_extension_arginfo.h"
// ... other header files
```

Configure your `build.zig`:

```zig
// Import the Phpz build system module
const Phpz = @import("phpz").Phpz;

// Fetch the phpz dependency declared in build.zig.zon
const phpz_dep = b.dependency("phpz", .{});
// Initialize Phpz: translates PHP C headers into Zig bindings
const phpz = Phpz.init(phpz_dep, .{
    .target = target,
    .optimize = optimize,
    // C header for translate-c
    .c_source_file = b.path("my_php_extension.h"),
    // Directory containing PHP header files (main/, Zend/, TSRM/, ext/).
    .php_include_dir = .{ .cwd_relative = "/usr/include/php" },
});

// Import the phpz module into your extension library
lib.root_module.addImport("phpz", phpz.mod);

// Apply OS-specific linker settings (macOS undefined symbols, Windows php8.lib)
phpz.apply(lib);
```

Then `zig build` !

## Examples

Check out the [`examples/`](./examples/) directory for complete working examples.

## How It Works

```
  Build-time                      Compile-time            Runtime
  ──────────                      ────────────            ───────

  stub.php                        Zig source
     │                               │
     │ php-src/build/gen_stub.php    │
     ▼                               │
  arginfo.h                          │
  [ext_functions]                    │
  [register_class_*]                 │
  [register_{name}_symbols]          │
     │                               │
     │ translate-c (zig build)       │
     ▼                               ▼
  PHP C bindings ─────────────► phpz comptime:
  (php_c module)                ├─ phpz.function() → zif_* export
                                ├─ Class.method()  → zim_* export
                                ├─ phpz.Class(T)   → wrapper type
                                └─ phpz.module()   → get_module() export
                                                             │
                                                             ├─── PHP loads .so
                                                             │
                                                             ▼
                                                        module_startup
                                                        ├─ register_{name}_symbols   (constants)
                                                        ├─ register_class_*          (classes)
                                                        ├─ ini_entries
                                                        └─ user hook
```

1. **Build-time** — `gen_stub.php` generates `arginfo.h` from `.stub.php`, containing function metadata and `register_*` symbols. `translate-c` converts PHP C headers into Zig bindings.
2. **Compile-time** — `phpz.function()` exports `zif_*` wrappers, `phpz.Class()` creates wrapper types, `phpz.module()` exports `get_module()` for the dynamic loader.
3. **Runtime** — PHP loads `.so` → `get_module()` → `module_startup` calls `register_{name}_symbols` (constants) and `register_class_*` (classes), then INI entries and user hook.
