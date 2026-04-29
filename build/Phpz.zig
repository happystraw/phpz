//! Phpz Build System Integration
//!
//! This module provides utilities for building PHP extensions with Zig.
//! It handles C header translation, PHP include paths setup, and module creation.
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
    ///   - win32/ (windows only)
    php_include_root: ?Build.LazyPath = null,

    /// Build as a shared library (.so/.dll/.dylib) for PHP to load dynamically.
    /// Set to false for static linking (less common for PHP extensions).
    shared: bool = true,
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
            // Import PHP C bindings as "php_c"
            .{ .name = "php_c", .module = createPhpCModule(b, options) },
        },
    });

    // Create build options for conditional compilation
    const mod_opts = b.addOptions();
    mod_opts.addOption(bool, "shared", options.shared);
    mod.addOptions("phpz_options", mod_opts);

    return .{ .mod = mod };
}

pub fn createPhpCModule(b: *Build, options: Options) *Build.Module {
    // This method uses an external dependency for C translation.
    const translate_c_dep = b.dependency("translate_c", .{});
    const php_c: Translator = .init(translate_c_dep, .{
        .c_source_file = options.c_source_file,
        .target = options.target,
        .optimize = options.optimize,
        .strict_flex_arrays = .@"1",
    });
    if (options.target.query.isNative() and options.target.result.os.tag == .linux) {
        // Add Zig's C include path (for stdint.h, stddef.h, etc.)
        if (b.graph.zig_lib_directory.path) |path| {
            php_c.addIncludePath(.{ .cwd_relative = b.fmt("{s}/include", .{path}) });
        }
    }
    // phpz.h
    php_c.addIncludePath(b.path("build"));

    // Configure PHP include paths for the C preprocessor
    if (options.php_include_root) |root| {
        php_c.addIncludePath(root);
        php_c.addIncludePath(root.path(b, "main"));
        php_c.addIncludePath(root.path(b, "Zend"));
        php_c.addIncludePath(root.path(b, "TSRM"));
        switch (options.target.result.os.tag) {
            .windows => php_c.addIncludePath(root.path(b, "win32")),
            else => {},
        }
    }
    return php_c.mod;
}

const std = @import("std");
const Build = std.Build;
const builtin = @import("builtin");

const Translator = @import("translate_c").Translator;
