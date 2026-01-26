const std = @import("std");

const Phpz = @import("phpz").Phpz;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const php_include_root = b.option([]const u8, "php-include-root", "PHP root include directory path") orelse "/usr/include/php";
    const ext_shared = b.option(bool, "ext-shared", "Build as a shared PHP extension") orelse true;
    const build_static = b.option(bool, "build-static", "Build as static library for linking") orelse false;

    const phpz_dep = b.dependency("phpz", .{});
    const phpz: Phpz = .init(phpz_dep, .{
        .c_source_file = b.path("my_php_extension.h"),
        .target = target,
        .optimize = optimize,
        .php_include_root = .{
            .cwd_relative = php_include_root,
        },
        .shared = ext_shared,
    });

    const ext_lib = b.addLibrary(.{
        .name = "my_php_extension",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "phpz", .module = phpz.mod },
            },
        }),
        .linkage = if (build_static) .static else .dynamic,
    });

    if (ext_shared and !build_static) {
        // for zig build system
        const install_file = b.addInstallFileWithDir(
            ext_lib.getEmittedBin(),
            .{ .custom = "../modules" },
            "my_php_extension.so",
        );
        install_file.step.dependOn(&ext_lib.step);
        b.getInstallStep().dependOn(&install_file.step);
    } else {
        // for php build system
        b.installArtifact(ext_lib);
    }

    const test_step = b.step("test", "Test the PHP extension");
    const test_cmd = b.addSystemCommand(&[_][]const u8{ "php", "-dextension=./modules/my_php_extension.so", "test.php" });
    const test_info_cmd = b.addSystemCommand(&[_][]const u8{ "php", "-dextension=./modules/my_php_extension.so", "--ri", "my_php_extension" });
    test_cmd.step.dependOn(b.getInstallStep());
    test_info_cmd.step.dependOn(b.getInstallStep());
    test_cmd.step.dependOn(&test_info_cmd.step);

    test_step.dependOn(&test_cmd.step);
}
