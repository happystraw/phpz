const std = @import("std");

const Phpz = @import("phpz").Phpz;

const package = @import("build.zig.zon");
const extension_name = @tagName(package.name);

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const php_include_dir = b.option([]const u8, "php-include-dir", "Matching PHP headers") orelse "/usr/include/php";
    const php_lib_dir = b.option([]const u8, "php-lib-dir", "PHP library search directory");
    const shared = b.option(bool, "shared", "Link against a shared PHP library (default: false)") orelse false;
    const libc_file = b.option([]const u8, "libc-file", "Libc paths file");
    const windows_zts = b.option(bool, "windows-zts", "Thread-safe PHP build") orelse false;
    const windows_debug = b.option(bool, "windows-debug", "Debug PHP build") orelse false;
    const libraries = b.option([]const []const u8, "link-lib", "Additional libraries to link (repeatable)") orelse &.{};
    const frameworks = b.option([]const []const u8, "link-framework", "Additional macOS frameworks to link (repeatable)") orelse &.{};
    const symbols = b.option([]const []const u8, "force-undefined-symbol", "Symbols to resolve from static libraries (repeatable)") orelse &.{};

    const phpz_dep = b.dependency("phpz", .{});
    const phpz = Phpz.init(phpz_dep, .{
        .translator = .{
            .c_source_file = b.path("custom_sapi.h"),
            .target = target,
            .optimize = optimize,
        },
        .php_include_dir = .{ .cwd_relative = php_include_dir },
        .php_lib_dir = if (php_lib_dir) |dir| .{ .cwd_relative = dir } else null,
        .libc_file = if (libc_file) |path| .{ .cwd_relative = path } else null,
        .windows_zts = windows_zts,
        .windows_debug = windows_debug,
        .shared = shared,
    });
    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const exe = phpz.addSapiExecutable(b, .{
        .name = "custom-sapi",
        .root_module = mod,
        // SPC's Windows static libraries use the static C runtime.
        .linkage = if (target.result.os.tag == .windows and !shared) .static else null,
    });
    for (libraries) |name| mod.linkSystemLibrary(name, .{
        .use_pkg_config = .no,
        .preferred_link_mode = if (shared) .dynamic else .static,
    });
    for (frameworks) |name| mod.linkFramework(name, .{});
    for (symbols) |name| exe.forceUndefinedSymbol(name);
    if (target.result.os.tag != .windows and shared) {
        if (php_lib_dir) |dir| mod.addRPath(.{ .cwd_relative = dir });
    }
    b.installArtifact(exe);
    const test_step = b.step("run-tests", "Test the custom SAPI executable");
    const run = b.addSystemCommand(&.{"php"});
    run.addFileArg(b.path("tests/run.php"));
    run.addArtifactArg(exe);
    test_step.dependOn(&run.step);

    // Regenerate arginfo only when explicitly requested.
    const gen_stub_step = b.step("gen-stub", "Regenerate arginfo from the PHP stub");
    const gen_stub_cmd = addRunPhpTool(b, phpz_dep.path("tools/php/gen_stub.php"), "build/gen_stub.php");
    gen_stub_cmd.addArg(extension_name ++ ".stub.php");
    gen_stub_step.dependOn(&gen_stub_cmd.step);
}

// Update the project-local tool from the bundle before running it.
fn addRunPhpTool(b: *std.Build, source: std.Build.LazyPath, destination: []const u8) *std.Build.Step.Run {
    const copy = std.Build.Step.UpdateSourceFiles.create(b);
    copy.addCopyFileToSource(source, destination);

    const run = b.addSystemCommand(&.{ "php", destination });
    run.setCwd(b.path("."));
    run.has_side_effects = true;
    run.step.dependOn(&copy.step);
    return run;
}
