const std = @import("std");

const Phpz = @import("phpz").Phpz;

const package = @import("build.zig.zon");
const extension_name = @tagName(package.name);
const extension_version = package.version;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // PHP build options.
    const php_include_dir = b.option([]const u8, "php-include-dir", "PHP include directory (main/, Zend/, TSRM/, ext/)") orelse "/usr/include/php";
    const php_lib_dir = b.option([]const u8, "php-lib-dir", "Windows only: required PHP SDK library directory containing php8*.lib");
    const windows_zts = b.option(bool, "windows-zts", "Windows only: link against the thread-safe PHP library") orelse false;
    const windows_debug = b.option(bool, "windows-debug", "Windows only: build against a debug PHP SDK") orelse false;
    const libc_file = b.option([]const u8, "libc-file", "Libc paths file for C translation and extension compilation");

    // Initialize phpz and translate PHP headers.
    const phpz_dep = b.dependency("phpz", .{});
    const phpz = Phpz.init(phpz_dep, .{
        .translator = .{
            .c_source_file = b.path("bench_zig.h"),
            .target = target,
            .optimize = optimize,
        },
        .libc_file = if (libc_file) |file| .{ .cwd_relative = file } else null,
        .php_include_dir = .{ .cwd_relative = php_include_dir },
        .php_lib_dir = if (php_lib_dir) |lib_dir| .{ .cwd_relative = lib_dir } else null,
        .windows_zts = windows_zts,
        .windows_debug = windows_debug,
    });

    // Build the PHP extension library.
    const extension = phpz.addExtension(b, .{
        .name = extension_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .dynamic,
    });

    // Pass extension metadata to Zig source.
    const extension_info = b.addOptions();
    extension_info.addOption([:0]const u8, "name", extension_name);
    extension_info.addOption([:0]const u8, "version", extension_version);
    extension.root_module.addOptions("extension_info", extension_info);

    // Copy the extension to modules/.
    const extension_filename = if (target.result.os.tag == .windows)
        "php_" ++ extension_name ++ ".dll"
    else
        extension_name ++ ".so";

    const extension_file = std.Build.Step.UpdateSourceFiles.create(b);
    extension_file.addCopyFileToSource(extension.getEmittedBin(), b.fmt("modules/{s}", .{extension_filename}));
    b.getInstallStep().dependOn(&extension_file.step);

    // Add PHPT test step.
    const run_tests_step = b.step("run-tests", "Run PHPT tests");
    const test_phpt_cmd = b.addSystemCommand(&[_][]const u8{
        "php",
        "run-tests.php",
        "-q",
        "--show-diff",
        "-d",
        b.fmt("extension=modules/{s}", .{extension_filename}),
    });
    test_phpt_cmd.step.dependOn(b.getInstallStep());
    run_tests_step.dependOn(&test_phpt_cmd.step);
}
