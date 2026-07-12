const std = @import("std");

pub const Phpz = @import("./build/Phpz.zig");

const BuildOptions = struct {
    php_include_dir: []const u8,
    php_lib_dir: ?[]const u8,
    libc_file: ?[]const u8,
    windows_zts: bool,
    windows_debug: bool,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,

    fn getLibCFilePath(self: BuildOptions) ?std.Build.LazyPath {
        return if (self.libc_file) |libc_file| .{ .cwd_relative = libc_file } else null;
    }
};

pub fn build(b: *std.Build) void {
    const options = BuildOptions{
        .php_include_dir = b.option([]const u8, "php-include-dir", "PHP include directory (main/, Zend/, TSRM/, ext/)") orelse "/usr/include/php",
        .php_lib_dir = b.option([]const u8, "php-lib-dir", "Windows only: required PHP SDK library directory containing php8*.lib"),
        .windows_zts = b.option(bool, "windows-zts", "Windows only: link against the thread-safe PHP library") orelse false,
        .windows_debug = b.option(bool, "windows-debug", "Windows only: build against a debug PHP SDK") orelse false,
        .libc_file = b.option([]const u8, "libc-file", "Libc paths file for C translation and extension compilation"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    };
    const mod = createPhpzModule(b, options);

    b.default_step = addCheckStep(b, mod, options);
    addGenerateDocsStep(b, mod, options);
    addTestExamplesStep(b, options);
    addTestStep(b, mod, options);
}

fn createPhpzModule(b: *std.Build, options: BuildOptions) *std.Build.Module {
    return Phpz.initInner(b, .{
        .translator = .{
            .c_source_file = b.path("build/phpz.h"),
            .target = options.target,
            .optimize = options.optimize,
        },
        .libc_file = options.getLibCFilePath(),
        .php_include_dir = .{ .cwd_relative = options.php_include_dir },
        .php_lib_dir = if (options.php_lib_dir) |d| .{ .cwd_relative = d } else null,
        .windows_zts = options.windows_zts,
        .windows_debug = options.windows_debug,
    }).mod;
}

fn addCheckStep(b: *std.Build, mod: *std.Build.Module, options: BuildOptions) *std.Build.Step {
    const lib_check = b.addLibrary(.{
        .name = "phpz",
        .root_module = mod,
    });
    lib_check.setLibCFile(options.getLibCFilePath());
    const check = b.step("check", "Check that phpz builds correctly");
    check.dependOn(&lib_check.step);
    return check;
}

fn addGenerateDocsStep(b: *std.Build, mod: *std.Build.Module, options: BuildOptions) void {
    const doc_step = b.step("docs", "Generate documentation for phpz");

    // Generate docs for main library (src/root.zig)
    const doc_obj = b.addObject(.{
        .name = "phpz",
        .root_module = mod,
    });
    doc_obj.setLibCFile(options.getLibCFilePath());
    const install_docs = b.addInstallDirectory(.{
        .source_dir = doc_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/lib",
    });
    doc_step.dependOn(&install_docs.step);

    // Generate docs for build system (build/Phpz.zig)
    const build_doc_obj = b.addObject(.{
        .name = "phpz-build",
        .root_module = b.createModule(.{
            .root_source_file = b.path("build/Phpz.zig"),
            .target = mod.resolved_target,
            .optimize = mod.optimize,
        }),
    });
    build_doc_obj.setLibCFile(options.getLibCFilePath());
    const install_build_docs = b.addInstallDirectory(.{
        .source_dir = build_doc_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/build",
    });
    doc_step.dependOn(&install_build_docs.step);
}

fn addTestStep(b: *std.Build, mod: *std.Build.Module, options: BuildOptions) void {
    const test_lib = b.addTest(.{
        .root_module = mod,
    });
    test_lib.setLibCFile(options.getLibCFilePath());
    const step = b.step("test", "Run unit tests");
    step.dependOn(&test_lib.step);

    for ([_][]const u8{
        "tools/check_arginfo.zig",
        "tools/windows_patcher.zig",
    }) |path| {
        const tool_tests = b.addTest(.{
            .name = b.fmt("{s}-tests", .{std.fs.path.stem(path)}),
            .root_module = b.createModule(.{
                .root_source_file = b.path(path),
                .target = b.graph.host,
                .optimize = options.optimize,
            }),
        });
        step.dependOn(&b.addRunArtifact(tool_tests).step);
    }
}

fn addTestExamplesStep(b: *std.Build, options: BuildOptions) void {
    const step = b.step("test-examples", "Run example tests for phpz");
    const examples = [_][]const u8{
        "skeleton",
        "my_php_extension",
    };
    inline for (examples) |test_example| {
        const test_cmd = b.addSystemCommand(&[_][]const u8{ "zig", "build", "test" });
        test_cmd.addArg(b.fmt("-Dphp-include-dir={s}", .{options.php_include_dir}));
        test_cmd.addArg(b.fmt("-Doptimize={s}", .{@tagName(options.optimize)}));
        if (options.libc_file) |libc_file| {
            const absolute_path = std.fs.path.resolve(b.allocator, &.{libc_file}) catch @panic("OOM");
            test_cmd.addArg(b.fmt("-Dlibc-file={s}", .{absolute_path}));
        }
        if (!options.target.query.isNativeTriple()) {
            test_cmd.addArg(b.fmt("-Dtarget={s}", .{options.target.query.zigTriple(b.allocator) catch unreachable}));
        }
        if (options.target.result.os.tag == .windows) {
            if (options.php_lib_dir) |lib_dir| {
                test_cmd.addArg(b.fmt("-Dphp-lib-dir={s}", .{lib_dir}));
            }
            test_cmd.addArg(b.fmt("-Dwindows-zts={}", .{options.windows_zts}));
            test_cmd.addArg(b.fmt("-Dwindows-debug={}", .{options.windows_debug}));
        }
        test_cmd.setCwd(b.path("examples").join(b.allocator, test_example) catch unreachable);
        step.dependOn(&test_cmd.step);
    }
}
