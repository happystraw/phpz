//! Phpz Build System Integration
//!
//! This module provides utilities for building PHP extensions with Zig.
//! It handles C header translation, PHP include paths setup, and module creation.
const Phpz = @This();

/// The compiled Phpz module with PHP extension support.
mod: *Build.Module,

/// Advanced access to the translator used to produce the PHP C bindings.
c: Translator,

options: Options,

/// Configuration options for building PHP extensions with Zig
pub const Options = struct {
    /// Options passed to the PHP C translator.
    /// Phpz forces `strict_flex_arrays` to `.@"1"`.
    translator: Translator.Options,

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
    const c = createPhpCTranslator(b, options);
    const mod = b.createModule(.{
        .target = options.translator.target,
        .optimize = options.translator.optimize,
        .root_source_file = b.path("src/root.zig"),
        .imports = &.{
            // Import PHP C bindings as "php_c"
            .{ .name = "php_c", .module = c.mod },
        },
    });

    // Create build options for conditional compilation
    const mod_opts = b.addOptions();
    mod_opts.addOption(bool, "shared", options.shared);
    mod_opts.addOption(usize, "debug_leak_trace_frames", options.debug_leak_trace_frames);
    mod.addOptions("phpz_options", mod_opts);

    return .{ .mod = mod, .c = c, .options = options };
}

fn createPhpCTranslator(b: *Build, options: Options) Translator {
    const translate_c_dep = b.dependency("translate_c", .{});
    var translator_options = options.translator;
    translator_options.strict_flex_arrays = .@"1";

    const c: Translator = .init(translate_c_dep, translator_options);
    if (translator_options.target.query.isNative() and translator_options.target.result.os.tag == .linux) {
        // FIXME: remove in zig 0.17.0
        // Add Zig's C include path (for stdint.h, stddef.h, etc.)
        if (b.graph.zig_lib_directory.path) |path| {
            c.addIncludePath(.{ .cwd_relative = b.fmt("{s}/include", .{path}) });
        }
    }
    // phpz.h
    c.addIncludePath(b.path("build"));

    // Configure PHP include paths for the C preprocessor
    if (options.php_include_dir) |root| {
        c.addIncludePath(root);
        c.addIncludePath(root.path(b, "main"));
        c.addIncludePath(root.path(b, "Zend"));
        c.addIncludePath(root.path(b, "TSRM"));
        c.addIncludePath(root.path(b, "ext"));
        if (translator_options.target.result.os.tag == .windows) {
            c.defineCMacro("ZEND_WIN32", "1");
            c.defineCMacro("PHP_WIN32", "1");
            c.defineCMacro("WINDOWS", "1");
        }
    }

    return c;
}

/// Apply OS-specific linker settings to a PHP extension shared library.
pub fn apply(self: Phpz, lib: *Build.Step.Compile) void {
    switch (self.options.translator.target.result.os.tag) {
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

const std = @import("std");
const Build = std.Build;

const Translator = @import("translate_c").Translator;
