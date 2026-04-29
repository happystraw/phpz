const std = @import("std");

const Phpz = @import("phpz").Phpz;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const php_include_root = b.option([]const u8, "php-include-root", "PHP root include directory path") orelse "/usr/include/php";

    const phpz_dep = b.dependency("phpz", .{});
    const phpz: Phpz = .init(phpz_dep, .{
        .c_source_file = b.path("pjs.h"),
        .target = target,
        .optimize = optimize,
        .php_include_root = .{
            .cwd_relative = php_include_root,
        },
    });

    const quickjs_dep = b.dependency("quickjs", .{ .target = target, .optimize = optimize });

    const ext_name = "pjs";
    const ext_lib = b.addLibrary(.{
        .name = ext_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "phpz", .module = phpz.mod },
                .{ .name = "quickjs", .module = quickjs_dep.module("quickjs") },
            },
        }),
        .use_llvm = true,
        .linkage = .dynamic,
    });

    // On macos, allow undefined symbols to be resolved at runtime by PHP
    if (target.result.os.tag == .macos) {
        ext_lib.linker_allow_shlib_undefined = true;
    }
    // On Windows, the PHP extension DLL must be linked against php8.lib
    // which lives in <prefix>/lib next to <prefix>/include in the PHP SDK.
    if (target.result.os.tag == .windows) {
        const php_lib_dir = b.option([]const u8, "php-lib-dir", "PHP library directory (Windows only)") orelse "";
        if (php_lib_dir.len > 0) {
            ext_lib.root_module.addLibraryPath(.{ .cwd_relative = php_lib_dir });
        }
        ext_lib.root_module.linkSystemLibrary("php8", .{});
    }

    const ext_filename = if (target.result.os.tag == .windows)
        "php_" ++ ext_name ++ ".dll"
    else
        ext_name ++ ".so";

    // for zig build system
    const install_file = b.addInstallFileWithDir(
        ext_lib.getEmittedBin(),
        .{ .custom = "../modules" },
        ext_filename,
    );
    install_file.step.dependOn(&ext_lib.step);
    b.getInstallStep().dependOn(&install_file.step);

    const ext_arg = b.fmt("-dextension=./modules/{s}", .{ext_filename});
    const test_step = b.step("test-extension", "Test the PHP extension");
    const test_cmd = b.addSystemCommand(&[_][]const u8{ "php", ext_arg, "test.php" });
    const test_info_cmd = b.addSystemCommand(&[_][]const u8{ "php", ext_arg, "--ri", ext_name });
    test_cmd.step.dependOn(b.getInstallStep());
    test_info_cmd.step.dependOn(b.getInstallStep());
    test_step.dependOn(&test_cmd.step);
    test_step.dependOn(&test_info_cmd.step);
}
