const std = @import("std");

const Phpz = @import("phpz").Phpz;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const php_include_root = b.option([]const u8, "php-include-root", "PHP root include directory path") orelse "/usr/include/php";
    const ext_shared = b.option(bool, "ext-shared", "Build as a shared PHP extension") orelse true;

    const phpz_dep = b.dependency("phpz", .{});
    const phpz: Phpz = .init(phpz_dep, .{
        .c_source_file = b.path("pjs.h"),
        .target = target,
        .optimize = optimize,
        .php_include_root = .{
            .cwd_relative = php_include_root,
        },
        .shared = ext_shared,
    });

    const quickjs_dep = b.dependency("quickjs", .{ .target = target, .optimize = optimize });

    const ext_lib = b.addLibrary(.{
        .name = "pjs",
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

    if (ext_shared) {
        // for zig build system
        const install_file = b.addInstallFileWithDir(
            ext_lib.getEmittedBin(),
            .{ .custom = "../modules" },
            "pjs.so",
        );
        install_file.step.dependOn(&ext_lib.step);
        b.getInstallStep().dependOn(&install_file.step);
    } else {
        // for php build system
        b.installArtifact(ext_lib);
    }

    const test_step = b.step("test", "Test the PHP extension");
    const test_cmd = b.addSystemCommand(&[_][]const u8{
        "php",
        "-dextension=./modules/pjs.so",
        "test.php",
    });
    const test_info_cmd = b.addSystemCommand(&[_][]const u8{
        "php",
        "-dextension=./modules/pjs.so",
        "--ri",
        "pjs",
    });
    test_cmd.step.dependOn(b.getInstallStep());
    test_info_cmd.step.dependOn(b.getInstallStep());
    test_cmd.step.dependOn(&test_info_cmd.step);

    test_step.dependOn(&test_cmd.step);
}
