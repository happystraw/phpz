# Phpz - Build PHP Extensions with Zig

A Zig framework for building PHP extensions with PHP C API bindings.

> **ℹ️ Note**: This is a personal experimental project — functionality works well for its intended use cases, but expect API changes as it evolves. Pin to a specific commit if you need stability.

## Requirements

- zig: 0.17.0-dev.1282+c0f9b51d8
- php: 8.2-8.5 (tested on linux/macos)

## Features

- **Module** — `phpz.module()` w/ `module_startup`, `module_shutdown`, `request_startup`, `request_shutdown`, `info` lifecycle hooks
- **Class & OOP** — `phpz.Class` (Zig `extern struct` ↦ PHP class, `init`/`deinit`), `phpz.SimpleClass` (interfaces, traits, enums, exceptions), methods, properties (static & instance), inheritance via `register()` hook
- **Functions** — `phpz.function()` with type-safe `Ctx` argument for `expectArgs`/`expectArg` parameter extraction (optional, nullable, raw zval) and `parse()` for complex type specs
- **Constants** — global and class constants via `const` in stub files, auto-registered during MINIT by `register_{name}_symbols`
- **Type-safe Zval** — checked conversions (`is`/`as`/`asOrDefault`), `Zval.Array` / `Zval.Object` builders, `Zval.Optional` nullable params, `Zval.native` raw pointer ops
- **Zend APIs** — `zend.Array` (HashTable CRUD, iterators, sort), `zend.String` (concat, hash), `zend.Object` (properties, calls, enum), `zend.ClassEntry`, `zend.Function`, `zend.Callable` (type-safe fci/fcc), `zend.PropertyInfo`, `zend.Reference`, `zend.Resource`
- **INI Settings** — `php.ini` directives with on-update callbacks and runtime getters
- **Error Handling** — PHP error triggers, exception throwing, argument validation errors
- **Memory** — Zig `Allocator` backed by PHP's `emalloc`, with DWARF leak tracing for debug builds
- **Auto-Registration** — stub-file-driven: functions (`ext_functions`) and constants (`const` in stub → `register_{name}_symbols`) are automatically registered at module startup; classes require an explicit `Class.register()` call in `module_startup_fn`

## Quick Start

Generate a PHP extension skeleton:

```bash
# Generate a new PHP extension skeleton
curl -fsSL https://raw.githubusercontent.com/happystraw/phpz/dev/tools/phpz_skel.php \
  | php -- --ext my_php_extension

# Run tests
cd my_php_extension
zig build test
```

## Manual Setup

> **💡 Tip**: For complete working examples, see the [`examples/`](./examples/) directory.

### 1. Add Phpz

Add `phpz` to your `build.zig.zon`

```bash
zig fetch --save git+https://github.com/happystraw/phpz
```

### 2. Generate arginfo.h

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

This will generate `my_php_extension_arginfo.h` containing all the necessary argument info definitions (functions, classes, constants, etc.).

### 3. Configure build.zig

Create a C header file (e.g., `my_php_extension.h`):

> [phpz.h](./build/phpz.h) provides the core C API needed for building PHP extensions (includes `php.h`, `Zend/zend_API.h` etc.).
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
    .translator = .{
        .target = target,
        .optimize = optimize,
        // C header for translate-c
        .c_source_file = b.path("my_php_extension.h"),
    },
    // Directory containing PHP header files (main/, Zend/, TSRM/, ext/).
    .php_include_dir = .{ .cwd_relative = "/usr/include/php" },
});

// Create the PHP extension library and import the phpz module.
const lib = phpz.addExtension(b, .{
    .name = "my_php_extension",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    }),
    .linkage = .dynamic,
});
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
                                                        module_startup  [auto]
                                                        ├─ register_{name}_symbols   (constants)
                                                        ├─ ini_entries
                                                        └─ user hook
                                                             └─ Class.register()     (classes) [manual]
```

1. **Build-time** — `gen_stub.php` generates `arginfo.h` from `.stub.php`, containing function metadata and `register_*` symbols. `translate-c` converts PHP C headers into Zig bindings.
2. **Compile-time** — `phpz.function()` exports `zif_*` wrappers, `phpz.Class()` creates wrapper types, `phpz.module()` exports `get_module()` for the dynamic loader.
3. **Runtime** — PHP loads `.so` → `get_module()`:

   | What | Registered by | When | How |
   | --- | --- | --- | --- |
   | Functions | `ext_functions` | Module init | Auto: set in module entry struct |
   | Constants | `register_{name}_symbols` | MINIT | Auto: called by `module_startup_func` |
   | Classes | `register_class_*` | MINIT | Manual: `Class.register()` in `module_startup_fn` |

   > Functions are resolved from the module entry when the extension loads; constants are registered during MINIT via the auto-generated `register_{name}_symbols`. Classes require an explicit `Class.register()` call in `module_startup_fn` — this gives you control over registration order and the opportunity to configure `ObjectHandlers` or parent classes.
