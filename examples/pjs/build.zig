const std = @import("std");

// Import the Phpz build system module
const Phpz = @import("phpz").Phpz;

pub fn build(b: *std.Build) void {
    // Standard Zig build options: target platform and optimization mode
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Directory containing PHP header files (main/, Zend/, TSRM/, ext/)
    const php_include_dir = b.option([]const u8, "php-include-dir", "PHP include directory (main/, Zend/, TSRM/, ext/)") orelse "/usr/include/php";
    // Windows only: PHP SDK lib directory containing php8.lib
    const php_lib_dir = b.option([]const u8, "php-lib-dir", "PHP SDK library directory (Windows only, contains php8.lib)");

    // Fetch the phpz dependency declared in build.zig.zon
    const phpz_dep = b.dependency("phpz", .{});
    // Initialize Phpz: translates PHP C headers into Zig bindings
    const phpz = Phpz.init(phpz_dep, .{
        .c_source_file = b.path("pjs.h"),
        .target = target,
        .optimize = optimize,
        .php_include_dir = .{ .cwd_relative = php_include_dir },
        .php_lib_dir = if (php_lib_dir) |d| .{ .cwd_relative = d } else null,
    });

    // QuickJS dependency for JavaScript runtime
    const quickjs_dep = b.dependency("quickjs", .{ .target = target, .optimize = optimize });

    // Create the PHP extension as a dynamic library (.so / .dll / .dylib)
    const php_ext_name = "pjs";
    const php_ext_lib = b.addLibrary(.{
        .name = php_ext_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .use_llvm = true,
        .linkage = .dynamic,
    });

    // Import the phpz and quickjs modules into your extension library
    php_ext_lib.root_module.addImport("phpz", phpz.mod);
    php_ext_lib.root_module.addImport("quickjs", quickjs_dep.module("quickjs"));

    // Apply OS-specific linker settings (macOS undefined symbols, Windows php8.lib)
    phpz.apply(php_ext_lib);

    // PHP expects extensions at a specific naming convention
    const php_ext_filename = if (target.result.os.tag == .windows)
        "php_" ++ php_ext_name ++ ".dll"
    else
        php_ext_name ++ ".so";

    // Copy the built extension to <project>/modules/
    const php_ext_file = std.Build.Step.UpdateSourceFiles.create(b);
    php_ext_file.addCopyFileToSource(php_ext_lib.getEmittedBin(), b.fmt("modules/{s}", .{php_ext_filename}));
    b.getInstallStep().dependOn(&php_ext_file.step);

    // Test step: runs PHPT tests
    const test_step = b.step("test", "Run PHPT tests");
    const test_phpt_cmd = b.addSystemCommand(&[_][]const u8{ "php", "run-tests.php" });
    test_phpt_cmd.step.dependOn(b.getInstallStep());
    test_step.dependOn(&test_phpt_cmd.step);
}
