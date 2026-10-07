//! Phpz Build System Integration
//!
//! This module provides utilities for building PHP extensions and SAPI hosts with Zig.
//! It handles C header translation, PHP include paths setup, and module creation.

const std = @import("std");
const Build = std.Build;

const Translator = @import("translate_c").Translator;

const Phpz = @This();

/// The phpz module imported by PHP extensions and SAPI hosts.
mod: *Build.Module,

/// Advanced access to the translator used to produce the PHP C bindings.
c: Translator,

options: Options,

/// Configuration for building PHP extensions and SAPI hosts with Zig.
pub const Options = struct {
    /// PHP header translation options, including the target and optimization mode.
    translator: Translator.Options,

    /// Libc paths file used by C translation and the generated build targets.
    libc_file: ?Build.LazyPath = null,

    /// Directory containing PHP header files (main/, Zend/, TSRM/, ext/).
    ///   Linux:   /usr/include/php
    ///   macOS:   /usr/local/php/include
    ///   Windows: C:\php-sdk\php-8.5.6-devel-vs17-x64\include
    php_include_dir: ?Build.LazyPath = null,

    /// Optional PHP library search directory.
    /// Omit to use the toolchain's library search paths, including on Windows.
    php_lib_dir: ?Build.LazyPath = null,

    /// For extensions, true builds a dynamic library and false builds a static library.
    /// For SAPI hosts, true links a shared PHP library and false links a static
    /// PHP library. Static PHP libraries can be built with StaticPHP (SPC).
    shared: bool = true,

    /// Maximum stack frames included in PHP memory leak reports.
    /// Applies when using php_allocator with a debug PHP build.
    debug_leak_trace_frames: usize = 3,

    /// Must match the Windows PHP build's thread-safety setting.
    windows_zts: bool = false,
    /// Must match the Windows PHP build's debug setting.
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

    // Include paths for phpz headers and the C wrapper.
    mod.addIncludePath(b.path("build"));
    if (options.php_include_dir) |root| {
        mod.addIncludePath(root);
        mod.addIncludePath(root.path(b, "main"));
        mod.addIncludePath(root.path(b, "Zend"));
        mod.addIncludePath(root.path(b, "TSRM"));
        mod.addIncludePath(root.path(b, "ext"));
    }
    if (options.php_lib_dir) |dir| mod.addLibraryPath(dir);
    switch (options.translator.target.result.os.tag) {
        .windows => {
            if (options.shared) {
                mod.linkSystemLibrary(libPhp(options), .{});
            } else {
                mod.addCMacro("PHP_EXPORTS", "1");
                mod.addCMacro("LIBZEND_EXPORTS", "1");
                mod.addCMacro("TSRM_EXPORTS", "1");
                mod.addCMacro("SAPI_EXPORTS", "1");
            }

            if (options.windows_zts) mod.addCMacro("ZTS", "1");
            mod.addCMacro("ZEND_DEBUG", if (options.windows_debug) "1" else "0");
            mod.addCMacro("ZEND_WIN32", "1");
            mod.addCMacro("PHP_WIN32", "1");
            mod.addCMacro("WINDOWS", "1");
            mod.addCMacro("WIN32", "1");
        },
        else => {},
    }
    if (!options.shared) {
        mod.addCMacro("PHPZ_STATIC_TSRMLS_CACHE", "1");
        mod.addCMacro("ZEND_ENABLE_STATIC_TSRMLS_CACHE", "1");
    }
    mod.addCSourceFile(.{ .file = b.path("build/phpz_wrapper.c") });

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
    if (translator_options.target.result.abi.isMusl()) c.defineCMacro("PHPZ_MUSL", "1");
    if (!options.shared) c.defineCMacro("PHPZ_STATIC_TSRMLS_CACHE", "1");

    // Configure PHP include paths for the C preprocessor
    if (options.php_include_dir) |root| {
        c.addIncludePath(root);
        c.addIncludePath(root.path(b, "main"));
        c.addIncludePath(root.path(b, "Zend"));
        c.addIncludePath(root.path(b, "TSRM"));
        c.addIncludePath(root.path(b, "ext"));

        switch (translator_options.target.result.os.tag) {
            .windows => {
                if (!options.shared) {
                    c.defineCMacro("PHP_EXPORTS", "1");
                    c.defineCMacro("LIBZEND_EXPORTS", "1");
                    c.defineCMacro("TSRM_EXPORTS", "1");
                    c.defineCMacro("SAPI_EXPORTS", "1");
                }
                if (options.windows_zts) c.defineCMacro("ZTS", "1");
                c.defineCMacro("ZEND_DEBUG", if (options.windows_debug) "1" else "0");
                c.defineCMacro("ZEND_WIN32", "1");
                c.defineCMacro("PHP_WIN32", "1");
                c.defineCMacro("WINDOWS", "1");
                c.defineCMacro("WIN32", "1");
                c.defineCMacro("_CRT_USE_BUILTIN_OFFSETOF", "1");
            },
            else => {},
        }
    } else {
        c.run.step.dependOn(&b.addFail("PHP headers are required; pass -Dphp-include-dir=<path-to-php-include>").step);
    }

    if (translator_options.target.result.os.tag == .windows) {
        if (translator_options.target.result.abi == .msvc) {
            if (options.shared) patchWindowsBindings(b, &c, translator_options);
        } else {
            c.run.step.dependOn(&b.addFail("Windows PHP extensions require the MSVC ABI; use -Dtarget=native-windows-msvc").step);
        }
    }

    return c;
}

/// Create a PHP extension library and attach the phpz module.
///
/// This also applies platform-specific linker settings required for PHP to
/// load the resulting shared library.
/// **Options.shared overrides the library linkage.**
pub fn addExtension(self: Phpz, b: *Build, options: Build.LibraryOptions) *Build.Step.Compile {
    const lib = b.addLibrary(options);
    if (self.options.shared) {
        lib.linkage = .dynamic;
    } else {
        lib.linkage = .static;
        lib.bundle_compiler_rt = true;
    }
    lib.root_module.addImport("phpz", self.mod);
    if (self.options.libc_file) |libc_file| lib.setLibCFile(libc_file);
    if (lib.root_module.resolved_target) |target| {
        switch (target.result.os.tag) {
            // macOS: allows undefined symbols to be resolved at runtime by PHP
            .macos => lib.linker_allow_shlib_undefined = true,
            else => {},
        }
    }
    if (b.option(bool, "check-arginfo", "Check that the generated arginfo header matches the extension stub (default: true)") orelse true) {
        lib.step.dependOn(addArginfoCheckStep(self, b, options.name));
    }
    return lib;
}

fn libPhp(options: Options) []const u8 {
    if (options.translator.target.result.os.tag != .windows) return "php";
    if (!options.shared) return "php8embed";
    return if (options.windows_debug)
        if (options.windows_zts) "php8ts_debug" else "php8_debug"
    else if (options.windows_zts) "php8ts" else "php8";
}

/// Build a standalone SAPI host against an existing PHP library.
/// Provide matching PHP headers and a library discoverable through php_lib_dir
/// or the toolchain's search paths.
/// Add transitive dependencies and runtime search paths through the returned target.
/// Use separate Phpz instances for extensions and SAPI hosts.
pub fn addSapiExecutable(self: Phpz, b: *Build, options: Build.ExecutableOptions) *Build.Step.Compile {
    const exe = b.addExecutable(options);
    exe.root_module.addImport("phpz", self.mod);
    const name = libPhp(self.options);
    if (!exe.dependsOnSystemLibrary(name)) exe.root_module.linkSystemLibrary(name, .{
        .use_pkg_config = .no,
        .preferred_link_mode = if (self.options.shared) .dynamic else .static,
        .search_strategy = .no_fallback,
    });
    exe.rdynamic = true;
    if (self.options.libc_file) |file| exe.setLibCFile(file);
    return exe;
}

fn addArginfoCheckStep(self: Phpz, b: *Build, extension_name: []const u8) *Build.Step {
    const checker = b.addExecutable(.{
        .name = "check-arginfo",
        .root_module = b.createModule(.{
            .root_source_file = self.mod.owner.path("tools/check_arginfo.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    const run = b.addRunArtifact(checker);
    run.setName(b.fmt("check {s} arginfo", .{extension_name}));
    run.addFileArg(b.path(b.fmt("{s}.stub.php", .{extension_name})));
    run.addFileArg(b.path(b.fmt("{s}_arginfo.h", .{extension_name})));
    return &run.step;
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
