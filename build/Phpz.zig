//! Phpz Build System Integration
//!
//! This module provides utilities for building PHP extensions with Zig.
//! It handles C header translation, PHP include paths setup, and module creation.
const Phpz = @This();

/// The compiled Phpz module with PHP extension support
mod: *Build.Module,

options: Options,

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

    /// Directory containing PHP header files (main/, Zend/, TSRM/, ext/).
    ///   Linux:   /usr/include/php
    ///   macOS:   /usr/local/php/include
    ///   Windows: C:\php-sdk\php-8.5.6-devel-vs17-x64\include
    php_include_dir: ?Build.LazyPath = null,

    /// Windows only: directory containing php8.lib (usually <sdk>/lib).
    php_lib_dir: ?Build.LazyPath = null,

    /// Build as a shared library for PHP to load dynamically.
    /// Set to false for static linking (less common for PHP extensions).
    shared: bool = true,

    /// Maximum stack frames captured for memory leak traceback when
    /// `ZEND_DEBUG=1` and using `php_allocator`. Each frame is resolved
    /// to `file:line:column` via DWARF debug info and included in PHP's
    /// leak reports. Has no effect when using a different allocator.
    debug_leak_trace_frames: usize = 3,
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
    mod_opts.addOption(usize, "debug_leak_trace_frames", options.debug_leak_trace_frames);
    mod.addOptions("phpz_options", mod_opts);

    return .{ .mod = mod, .options = options };
}

/// Apply OS-specific linker settings to a PHP extension shared library.
pub fn apply(self: Phpz, lib: *Build.Step.Compile) void {
    switch (self.options.target.result.os.tag) {
        // macOS: allows undefined symbols to be resolved at runtime by PHP
        .macos => lib.linker_allow_shlib_undefined = true,
        // Windows: links against php8.lib in the PHP SDK
        .windows => {
            if (self.options.php_lib_dir) |dir| {
                lib.root_module.addLibraryPath(dir);
            }
            lib.root_module.linkSystemLibrary("php8", .{});
        },
        else => {},
    }
}

fn createPhpCModule(b: *Build, options: Options) *Build.Module {
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
    if (options.php_include_dir) |root| {
        php_c.addIncludePath(root);
        php_c.addIncludePath(root.path(b, "main"));
        php_c.addIncludePath(root.path(b, "Zend"));
        php_c.addIncludePath(root.path(b, "TSRM"));
        php_c.addIncludePath(root.path(b, "ext"));
        if (options.target.result.os.tag == .windows) {
            php_c.defineCMacro("ZEND_WIN32", "1");
            php_c.defineCMacro("PHP_WIN32", "1");
            php_c.defineCMacro("WINDOWS", "1");
        }
    }
    return php_c.mod;
}

const std = @import("std");
const Build = std.Build;

const Translator = @import("translate_c").Translator;
