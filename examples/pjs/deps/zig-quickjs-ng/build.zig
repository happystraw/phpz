const std = @import("std");
const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // C headers
    // const c = translateC(b, target, optimize);
    // const c_mod = c.addModule("quickjs_c");
    const c_mod = createExternalTranslateCModule(b, target, optimize);
    // _ = b.addModule("quickjs_c", .{
    //     .root_source_file = c_mod.root_source_file,
    //     .target = c_mod.resolved_target,
    //     .optimize = c_mod.optimize,
    //     .link_libc = c_mod.link_libc,
    // });

    // Library
    const lib = try library(b, target, optimize);
    b.installArtifact(lib);

    // Zig module
    const mod = b.addModule("quickjs", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{
            .name = "quickjs_c",
            .module = c_mod,
        }},
    });

    // Tests
    const tests = b.addTest(.{
        .root_module = mod,
        // Compiler crash without this.
        .use_llvm = true,
    });
    tests.root_module.linkLibrary(lib);
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}

pub fn translateC(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.TranslateC {
    const upstream = b.dependency("quickjs", .{});

    const translate = b.addTranslateC(.{
        .root_source_file = upstream.path("quickjs.h"),
        .target = target,
        .optimize = optimize,
    });

    translate.addIncludePath(upstream.path(""));
    return translate;
}

// TODO: remove it, use zig builtin translate c when 0.16.0 is released
fn createExternalTranslateCModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const translate_c = b.dependency("translate_c", .{});
    const upstream = b.dependency("quickjs", .{});

    const t: Translator = .init(translate_c, .{
        .c_source_file = upstream.path("quickjs.h"),
        .target = target,
        .optimize = optimize,
    });
    t.addIncludePath(upstream.path(""));
    return t.mod;
}

pub fn library(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !*std.Build.Step.Compile {
    const upstream = b.dependency("quickjs", .{});

    const lib = b.addLibrary(.{
        .name = "quickjs-ng",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    lib.root_module.link_libc = true;

    lib.root_module.addIncludePath(upstream.path(""));
    lib.installHeader(
        upstream.path("quickjs.h"),
        "quickjs.h",
    );

    var flags: std.ArrayList([]const u8) = .empty;
    try flags.appendSlice(b.allocator, &.{
        "-D_GNU_SOURCE",
        "-funsigned-char",
        "-fno-omit-frame-pointer",
        "-fno-sanitize=undefined",
        "-fno-sanitize-trap=undefined",
        "-fvisibility=hidden",
    });
    lib.root_module.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = &.{
            "cutils.c",
            "dtoa.c",
            "libregexp.c",
            "libunicode.c",
            "quickjs.c",
        },
        .flags = flags.items,
    });

    return lib;
}
