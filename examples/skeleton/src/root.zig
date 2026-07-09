const std = @import("std");

const phpz = @import("phpz");

const counter = @import("classes/counter.zig");

comptime {
    phpz.function("hello", hello);
    phpz.function("greet", greet);

    phpz.module(.{
        .name = "skeleton",
        .version = "0.1.0",
        .classes = &.{counter.Class},
    });
}

// --- Functions ---

/// function hello(): void
fn hello() void {
    _ = phpz.printf("Hello from Zig!\n", .{});
}

/// function greet(string $name): string
fn greet(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
    }, {});
    const name = args[0];

    var buffer: [256]u8 = undefined;
    const result = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{name});
    ctx.ret.set(.string, result);
}
