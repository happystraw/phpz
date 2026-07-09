const std = @import("std");

// Import the Phpz build system module
const Phpz = @import("phpz").Phpz;

pub fn build(b: *std.Build) void {
    // Standard Zig build options: target platform and optimization mode
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Directory containing PHP header files (main/, Zend/, TSRM/, ext/)
    const php_include_dir = b.option([]const u8, "php-include-dir", "PHP include directory (main/, Zend/, TSRM/, ext/)") orelse "/usr/include/php";
    // Windows only: PHP SDK lib directory containing php8*.lib
    const php_lib_dir = b.option([]const u8, "php-lib-dir", "PHP SDK library directory (Windows only, contains php8*.lib)");
    const libc_file = b.option([]const u8, "libc", "Libc paths file for cross-compilation");
    const libc_file_path: ?std.Build.LazyPath = if (libc_file) |path| .{ .cwd_relative = path } else null;
    const windows_zts = b.option(bool, "windows-zts", "Windows only: link against the thread-safe PHP library") orelse false;

    // Fetch the phpz dependency declared in build.zig.zon
    const phpz_dep = b.dependency("phpz", .{});
    // Initialize Phpz: translates PHP C headers into Zig bindings
    const phpz = Phpz.init(phpz_dep, .{
        .translator = .{
            .c_source_file = b.path("my_php_extension.h"),
            .target = target,
            .optimize = optimize,
            .libc_file = libc_file_path,
        },
        .php_include_dir = .{ .cwd_relative = php_include_dir },
        .php_lib_dir = if (php_lib_dir) |d| .{ .cwd_relative = d } else null,
        .windows_zts = windows_zts,
    });

    // Create the PHP extension as a dynamic library (.so / .dll / .dylib)
    const php_ext_name = "my_php_extension";
    const php_ext_lib = phpz.addExtension(b, .{
        .name = php_ext_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .dynamic,
    });
    php_ext_lib.setLibCFile(libc_file_path);

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
    const test_phpt_cmd = b.addSystemCommand(&[_][]const u8{
        "php",
        "run-tests.php",
        "-q",
        "--show-diff",
        "-d",
        b.fmt("extension=modules/{s}", .{php_ext_filename}),
    });
    test_phpt_cmd.step.dependOn(b.getInstallStep());
    test_step.dependOn(&test_phpt_cmd.step);
}
