const std = @import("std");

const phpz = @import("phpz");

const counter = @import("classes/counter.zig");

fn startup() !void {
    counter.Class.register();
}

comptime {
    phpz.function("hello", hello);
    phpz.function("greet", greet);

    phpz.module(.{
        .name = "skeleton",
        .version = "0.1.0",
        .module_startup_fn = startup,
    });
}

// --- Functions ---

fn hello() void {
    _ = phpz.printf("Hello from Zig!\n", .{});
}

fn greet(ctx: phpz.Ctx) !void {
    var name: []u8 = undefined;
    try ctx.call.parse("s", .{ &name.ptr, &name.len });

    var buffer: [256]u8 = undefined;
    const result = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{name});
    ctx.ret.set(.string, result);
}
