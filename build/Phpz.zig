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

    /// Libc paths file used by both C translation and extension compilation.
    libc_file: ?Build.LazyPath = null,

    /// Directory containing PHP header files (main/, Zend/, TSRM/, ext/).
    ///   Linux:   /usr/include/php
    ///   macOS:   /usr/local/php/include
    ///   Windows: C:\php-sdk\php-8.5.6-devel-vs17-x64\include
    php_include_dir: ?Build.LazyPath = null,

    /// Windows only: directory containing the matching php8*.lib import library.
    php_lib_dir: ?Build.LazyPath = null,

    /// Build as a shared library for PHP to load dynamically.
    /// Set to false for static linking (less common for PHP extensions).
    shared: bool = true,

    /// Maximum stack frames captured for memory leak traceback when
    /// `ZEND_DEBUG=1` and using `php_allocator`. Each frame is resolved
    /// to `file:line:column` via DWARF debug info and included in PHP's
    /// leak reports. Has no effect when using a different allocator.
    debug_leak_trace_frames: usize = 3,

    windows_zts: bool = false,
    windows_debug: bool = false,
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
        .link_libc = true,
    });

    // Add phpz_wrapper.c to the build and include path for phpz.h
    mod.addIncludePath(b.path("build"));
    if (options.php_include_dir) |root| {
        mod.addIncludePath(root);
        mod.addIncludePath(root.path(b, "main"));
        mod.addIncludePath(root.path(b, "Zend"));
        mod.addIncludePath(root.path(b, "TSRM"));
        mod.addIncludePath(root.path(b, "ext"));
    }
    switch (options.translator.target.result.os.tag) {
        .windows => {
            if (options.php_lib_dir) |dir| mod.addLibraryPath(dir);
            const php_lib_name = if (options.windows_debug)
                if (options.windows_zts) "php8ts_debug" else "php8_debug"
            else if (options.windows_zts) "php8ts" else "php8";
            mod.linkSystemLibrary(php_lib_name, .{});

            if (options.windows_zts) mod.addCMacro("ZTS", "1");
            mod.addCMacro("ZEND_DEBUG", if (options.windows_debug) "1" else "0");
            mod.addCMacro("ZEND_WIN32", "1");
            mod.addCMacro("PHP_WIN32", "1");
            mod.addCMacro("WINDOWS", "1");
            mod.addCMacro("WIN32", "1");
        },
        else => {},
    }
    mod.addCSourceFile(.{ .file = b.path("build/phpz_wrapper.c") });

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

    // Override translator options managed by Phpz.
    translator_options.strict_flex_arrays = .@"1";
    translator_options.libc_file = options.libc_file;

    var c: Translator = .init(translate_c_dep, translator_options);
    // phpz.h
    c.addIncludePath(b.path("build"));
    c.defineCMacro("PHPZ_TRANSLATE_C", "1");

    // Configure PHP include paths for the C preprocessor
    if (options.php_include_dir) |root| {
        c.addIncludePath(root);
        c.addIncludePath(root.path(b, "main"));
        c.addIncludePath(root.path(b, "Zend"));
        c.addIncludePath(root.path(b, "TSRM"));
        c.addIncludePath(root.path(b, "ext"));

        switch (translator_options.target.result.os.tag) {
            .windows => {
                if (options.windows_zts) c.defineCMacro("ZTS", "1");
                c.defineCMacro("ZEND_DEBUG", if (options.windows_debug) "1" else "0");
                c.defineCMacro("ZEND_WIN32", "1");
                c.defineCMacro("PHP_WIN32", "1");
                c.defineCMacro("WINDOWS", "1");
                c.defineCMacro("WIN32", "1");
                c.defineCMacro("_CRT_USE_BUILTIN_OFFSETOF", "1");
            },
            .macos => {
                // FIXME: regression in translate_c
                c.defineCMacro("_Nonnull", "");
                c.defineCMacro("_Nullable", "");
                c.defineCMacro("_Null_unspecified", "");
            },
            else => {},
        }
    }

    if (translator_options.target.result.os.tag == .windows and translator_options.target.result.abi == .msvc) {
        patchWindowsBindings(b, &c, translator_options);
    }

    return c;
}

/// Create a PHP extension library and attach the phpz module.
///
/// This also applies platform-specific linker settings required for PHP to
/// load the resulting shared library.
pub fn addExtension(self: Phpz, b: *Build, options: Build.LibraryOptions) *Build.Step.Compile {
    options.root_module.addImport("phpz", self.mod);
    const lib = b.addLibrary(options);
    lib.setLibCFile(self.options.libc_file);
    switch (self.options.translator.target.result.os.tag) {
        // macOS: allows undefined symbols to be resolved at runtime by PHP
        .macos => lib.linker_allow_shlib_undefined = true,
        else => {},
    }
    return lib;
}

fn patchWindowsBindings(b: *Build, translate_c: *Translator, options: Translator.Options) void {
    const patcher = b.addExecutable(.{
        .name = "windows-patcher",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/windows_patcher.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    const run = b.addRunArtifact(patcher);
    run.setName("patch Windows PHP bindings");

    const raw_output_file = translate_c.output_file;
    run.addFileArg(raw_output_file);
    const name = std.fs.path.stem(b.fmt("{f}", .{options.c_source_file}));
    const output_file = run.addOutputFileArg(b.fmt("{s}.patched.zig", .{name}));

    translate_c.mod.root_source_file = output_file;
    translate_c.output_file = output_file;
}

const std = @import("std");
const Build = std.Build;

const Translator = @import("translate_c").Translator;
