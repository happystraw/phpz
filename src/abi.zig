const std = @import("std");
const builtin = @import("builtin");

pub const fn_cc: std.builtin.CallingConvention = if (builtin.os.tag == .windows and builtin.abi == .msvc)
    switch (builtin.cpu.arch) {
        .x86_64 => .{ .x86_64_vectorcall = .{} },
        .x86 => .{ .x86_vectorcall = .{} },
        else => .c,
    }
else
    .c;

pub const use_dll_import = builtin.os.tag == .windows and builtin.abi == .msvc and @import("phpz_options").shared;
