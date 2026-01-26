const std = @import("std");

pub const Phpz = @import("./build/Phpz.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const php_include_root = b.option([]const u8, "php-include-root", "PHP root include directory path") orelse "/usr/include/php";

    const php_ext_mod = Phpz.createPhpExtModule(b, .{
        .php_include_root = .{ .cwd_relative = php_include_root },
        .c_source_file = b.path("build/phpz.h"),
        .use_external_translator_c = true,
        .target = target,
        .optimize = optimize,
    });
    const phpz_mod = b.createModule(.{
        .link_libc = true,
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "php_ext", .module = php_ext_mod },
        },
    });
    const lib = b.addLibrary(.{
        .name = "phpz",
        .root_module = phpz_mod,
    });
    b.installArtifact(lib); // only for development

    // Documentation generation step
    const doc_step = b.step("doc", "Generate documentation for phpz");

    // Generate docs for main library (src/root.zig)
    const doc_obj = b.addObject(.{
        .name = "phpz",
        .root_module = phpz_mod,
    });
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
            .target = target,
            .optimize = optimize,
        }),
    });
    const install_build_docs = b.addInstallDirectory(.{
        .source_dir = build_doc_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/build",
    });
    doc_step.dependOn(&install_build_docs.step);

    // Test step: runs the test command from examples
    const test_step = b.step("test", "run examples tests");
    const test_cmd = b.addSystemCommand(&[_][]const u8{
        b.graph.zig_exe,
        "build",
        "test",
        b.fmt("-Dphp-include-root={s}", .{php_include_root}),
    });
    test_cmd.setCwd(b.path("examples/my_php_extension"));
    const test_pjs_cmd = b.addSystemCommand(&[_][]const u8{
        b.graph.zig_exe,
        "build",
        "test",
        b.fmt("-Dphp-include-root={s}", .{php_include_root}),
    });
    test_pjs_cmd.setCwd(b.path("examples/pjs"));
    test_step.dependOn(&test_cmd.step);
    test_step.dependOn(&test_pjs_cmd.step);
}
