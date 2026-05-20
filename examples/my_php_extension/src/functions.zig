const std = @import("std");

const phpz = @import("phpz");
const c = phpz.c;
const errors = phpz.errors;

const HumanClass = @import("classes.zig").human.Class;

fn hello() void {
    _ = phpz.printf("Hello from ZIG!\n", .{});
}

fn greet(ctx: phpz.Ctx) !void {
    var name: []u8 = undefined;
    try ctx.call.parse("s", .{ &name.ptr, &name.len });

    var buffer: [4096]u8 = undefined;
    const result: []const u8 = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{name});

    ctx.ret.set(.string, result);
}

fn human(ctx: phpz.Ctx) !void {
    var name: *c.zval = undefined;
    var age: ?*c.zval = null;

    try ctx.call.parse("z|z!", .{ &name, &age });

    const human_obj: *HumanClass = .new();
    try human_obj.construct(.{ name.*, if (age) |a| a.* else phpz.Zval.native.nil });

    ctx.ret.set(.object, &human_obj.std);
}

comptime {
    phpz.function("hello", hello);
    phpz.function("greet", greet);
    phpz.function("MyPHPExt\\human", human);
}
