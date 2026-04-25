const std = @import("std");

const phpz = @import("phpz");
const c = phpz.c;
const errors = phpz.errors;

const HumanClass = @import("classes.zig").human.Class;

fn hello() void {
    _ = phpz.printf("Hello from ZIG!\n", .{});
}

fn greet(frame: *phpz.CallFrame, ret: *phpz.Zval) !void {
    var name: []u8 = undefined;
    try frame.parse("s", .{ &name.ptr, &name.len });

    var buffer: [4096]u8 = undefined;
    const result: []const u8 = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{name});

    ret.set(.string, result);
}

fn human(frame: *phpz.CallFrame, ret: *phpz.Zval) !void {
    var name_zv: *c.zval = undefined;
    var age_zv: ?*c.zval = null;

    try frame.parse("z|z!", .{ &name_zv, &age_zv });

    const human_obj: *HumanClass = .new();
    var call_params = [_]c.zval{
        name_zv.*,
        if (age_zv) |age| age.* else phpz.Zval.raw.init(.null, {}),
    };
    var zval: c.zval = undefined;
    defer c.zval_ptr_dtor(&zval);
    try human_obj.call("__construct", &call_params, &zval);

    ret.set(.object, &human_obj.std);
}

comptime {
    phpz.function("hello", hello);
    phpz.function("greet", greet);
    phpz.function("MyPHPExt\\human", human);
}
