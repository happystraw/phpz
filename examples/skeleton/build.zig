const std = @import("std");

const Phpz = @import("phpz").Phpz;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const php_include_dir = b.option([]const u8, "php-include-dir", "PHP include directory (main/, Zend/, TSRM/, ext/)") orelse "/usr/include/php";
    const php_lib_dir = b.option([]const u8, "php-lib-dir", "PHP SDK library directory (Windows only, contains php8*.lib)");
    const libc_file = b.option([]const u8, "libc-file", "Libc paths file for C translation and extension compilation");
    const windows_zts = b.option(bool, "windows-zts", "Windows only: link against the thread-safe PHP library") orelse false;
    const windows_debug = b.option(bool, "windows-debug", "Windows only: build against a debug PHP SDK") orelse false;

    const phpz_dep = b.dependency("phpz", .{});
    const phpz = Phpz.init(phpz_dep, .{
        .translator = .{
            .c_source_file = b.path("skeleton.h"),
            .target = target,
            .optimize = optimize,
        },
        .libc_file = if (libc_file) |path| .{ .cwd_relative = path } else null,
        .php_include_dir = .{ .cwd_relative = php_include_dir },
        .php_lib_dir = if (php_lib_dir) |d| .{ .cwd_relative = d } else null,
        .windows_zts = windows_zts,
        .windows_debug = windows_debug,
    });

    const ext_name = "skeleton";
    const ext_lib = phpz.addExtension(b, .{
        .name = ext_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .dynamic,
    });

    const ext_filename = if (target.result.os.tag == .windows)
        "php_" ++ ext_name ++ ".dll"
    else
        ext_name ++ ".so";

    const ext_file = std.Build.Step.UpdateSourceFiles.create(b);
    ext_file.addCopyFileToSource(ext_lib.getEmittedBin(), b.fmt("modules/{s}", .{ext_filename}));
    b.getInstallStep().dependOn(&ext_file.step);

    const test_step = b.step("test", "Run PHPT tests");
    const test_phpt_cmd = b.addSystemCommand(&[_][]const u8{
        "php",
        "run-tests.php",
        "-q",
        "--show-diff",
        "-d",
        b.fmt("extension=modules/{s}", .{ext_filename}),
    });
    test_phpt_cmd.step.dependOn(b.getInstallStep());
    test_step.dependOn(&test_phpt_cmd.step);
}
