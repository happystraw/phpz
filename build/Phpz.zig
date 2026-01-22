//! Phpz Build System Integration
//!
//! This module provides utilities for building PHP extensions with Zig.
//! It handles C header translation, PHP include paths setup, and module creation.
//!
//! ## Usage
//!
//! In your build.zig, use this module as a dependency:
//!
//! ```zig
//! const phpz_dep = b.dependency("phpz", .{});
//! const phpz: Phpz = .init(phpz_dep, .{
//!     .c_source_file = b.path("my_extension.h"),
//!     .target = target,
//!     .optimize = optimize,
//!     .php_include_root = .{ .cwd_relative = "/usr/include/php" },
//!     .shared = true,
//!     .use_external_translator_c = false, // Use builtin translate-c (recommended)
//! });
//!
//! const ext_lib = b.addLibrary(.{
//!     .name = "my_extension",
//!     .root_module = b.createModule(.{
//!         .root_source_file = b.path("src/main.zig"),
//!         .imports = &.{
//!             .{ .name = "phpz", .module = phpz.mod },
//!         },
//!     }),
//!     .linkage = .dynamic,
//! });
//! ```
//!
//! ## PHP Extension Development
//!
//! Create a C header file (e.g., my_extension.h) that includes PHP headers:
//! ```c
//! #include <php.h>
//! #include <Zend/zend_API.h>
//! ```
//!
//! Then use the phpz module in your Zig code:
//! ```zig
//! const phpz = @import("phpz");
//! const c = phpz.c;
//! ```

const std = @import("std");
const Build = std.Build;

const Phpz = @This();

/// The compiled Phpz module with PHP extension support
mod: *Build.Module,

/// Configuration options for building PHP extensions with Zig
pub const Options = struct {
    /// Path to the C header file that includes PHP headers.
    /// This file will be processed by translate-c to generate Zig bindings.
    /// Example: b.path("my_extension.h")
    c_source_file: Build.LazyPath,

    /// Target platform configuration (cross-compilation support)
    target: Build.ResolvedTarget,

    /// Optimization mode (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall)
    optimize: std.builtin.OptimizeMode,

    /// Root directory containing PHP headers.
    /// Typically /usr/include/php on Linux.
    /// The build system will automatically append subdirectories:
    ///   - main/
    ///   - Zend/
    ///   - TSRM/
    php_include_root: ?Build.LazyPath = null,

    /// Build as a shared library (.so/.dll/.dylib) for PHP to load dynamically.
    /// Set to false for static linking (less common for PHP extensions).
    shared: bool = true,

    /// Deprecated: Use built-in translate-c instead. This option will be removed in Zig 0.16.0.
    use_external_translator_c: bool = true,
};

/// Initialize Phpz from a build dependency.
pub fn init(phpz_dep: *Build.Dependency, options: Options) Phpz {
    return initInner(phpz_dep.builder, options);
}

pub fn initInner(b: *Build, options: Options) Phpz {
    const mod = b.createModule(.{
        .target = options.target,
        .optimize = options.optimize,
        .root_source_file = b.path("src/root.zig"),
        .imports = &.{
            // Import PHP C bindings as "php_ext"
            .{ .name = "php_ext", .module = createPhpExtModule(b, options) },
        },
    });

    // Create build options for conditional compilation
    const mod_opts = b.addOptions();
    mod_opts.addOption(bool, "shared", options.shared);
    mod.addOptions("phpz_options", mod_opts);

    return .{ .mod = mod };
}

pub fn createPhpExtModule(b: *Build, options: Options) *Build.Module {
    if (options.use_external_translator_c) {
        // === DEPRECATED PATH: External translator-c ===
        // This method uses an external dependency for C translation.
        // Will be removed in a future version.
        const translate_c_dep = b.dependency("translate_c", .{});
        const Translator = @import("translate_c").Translator;
        const php_ext: Translator = .init(translate_c_dep, .{
            .c_source_file = options.c_source_file,
            .target = options.target,
            .optimize = options.optimize,
        });

        // Add Zig's C include path (for stdint.h, stddef.h, etc.)
        if (b.graph.zig_lib_directory.path) |path| {
            php_ext.addIncludePath(.{ .cwd_relative = b.fmt("{s}/include", .{path}) });
        }

        // Add PHP-specific include paths
        if (options.php_include_root) |root| {
            php_ext.addIncludePath(root);
            php_ext.addIncludePath(root.path(b, "main"));
            php_ext.addIncludePath(root.path(b, "Zend"));
            php_ext.addIncludePath(root.path(b, "TSRM"));
        }
        return php_ext.mod;
    }

    // === RECOMMENDED PATH: Builtin translate-c ===
    // Uses Zig's native C translation for better IDE support.
    const php_ext = b.addTranslateC(.{
        .root_source_file = options.c_source_file,
        .target = options.target,
        .optimize = options.optimize,
    });

    // Configure PHP include paths for the C preprocessor
    if (options.php_include_root) |root| {
        php_ext.addIncludePath(root);
        php_ext.addIncludePath(root.path(b, "main")); // PHP main headers
        php_ext.addIncludePath(root.path(b, "Zend")); // Zend engine headers
        php_ext.addIncludePath(root.path(b, "TSRM")); // Thread-safe resource manager
    }

    return php_ext.createModule();
}
