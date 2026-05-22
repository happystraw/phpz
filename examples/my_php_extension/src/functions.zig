const std = @import("std");

const phpz = @import("phpz");
const c = phpz.c;
const Zval = phpz.Zval;

const UserClass = @import("classes.zig").user.Class;

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

fn increment(ctx: phpz.Ctx) !void {
    var zv: *c.zval = undefined;
    try ctx.call.parse("z", .{&zv});

    const raw = if (Zval.native.is(zv, .reference))
        &Zval.native.asUnchecked(zv, .reference).val
    else
        zv;

    const current = Zval.native.asUnchecked(raw, .int);
    Zval.native.set(raw, .int, current + 1);
}

fn findById(ctx: phpz.Ctx) !void {
    ctx.ret.set(.null, {});
}

fn getDefaultUser(ctx: phpz.Ctx) !void {
    var name_zv = Zval.native.init(.string, "Default");
    defer Zval.native.dtor(&name_zv);
    const age_zv = Zval.native.init(.int, @as(i64, 25));

    const user: *UserClass = .new();
    try user.construct(.{ name_zv, age_zv });
    ctx.ret.set(.object, &user.std);
}

fn listStatuses(ctx: phpz.Ctx) !void {
    var arr = phpz.Zval.Array.empty(ctx.ret.ptr());
    try arr.append(.string, "active");
    try arr.append(.string, "inactive");
}

comptime {
    phpz.function("hello", hello);
    phpz.function("greet", greet);
    phpz.function("MyPHPExt\\increment", increment);
    phpz.function("MyPHPExt\\findById", findById);
    phpz.function("MyPHPExt\\getDefaultUser", getDefaultUser);
    phpz.function("MyPHPExt\\listStatuses", listStatuses);
}
