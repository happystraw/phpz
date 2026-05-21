# Phpz - Build PHP Extensions with Zig

A Zig framework for building PHP extensions with PHP C API bindings.

> **⚠️ Warning**: This is a toy project created to solve my own needs. The API changes frequently based on my needs, and force pushes are common. Like Zig itself, expect instability! 😄
>
> Feel free to use it, but pin to a specific commit if you need stability.

## Requirements

- zig: 0.16.0
- php: 8.2, 8.3, 8.4, 8.5 tested on linux/macos

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

Check out the [`examples/`](./examples/) directory for complete working examples:
