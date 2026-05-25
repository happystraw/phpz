const std = @import("std");

const phpz = @import("phpz");
const c = phpz.c;
const Zval = phpz.Zval;

const UserClass = @import("classes.zig").user.Class;
const StatusEnum = @import("classes.zig").status.Enum;

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
    const age_zv = Zval.native.init(.int, 25);

    const user: *UserClass = .new();
    try user.construct(.{ name_zv, age_zv });
    ctx.ret.set(.object, &user.std);
}

fn listStatuses(ctx: phpz.Ctx) !void {
    const cases_fn = StatusEnum.entry.findMethod("cases").?;

    var cases_zv: c.zval = undefined;
    cases_fn.callStatic(StatusEnum.entry, &cases_zv, .{});
    defer phpz.Zval.native.dtor(&cases_zv);

    var ret = phpz.Zval.Array.empty(ctx.ret.ptr());
    var cases = phpz.zend.Array.from(phpz.Zval.native.asUnchecked(&cases_zv, .array));
    var it = cases.iterator();
    while (it.next()) |entry| {
        const entry_obj = phpz.zend.Object.from(phpz.Zval.native.asUnchecked(entry.value, .object));
        const name = entry_obj.enumCaseName();
        const value = phpz.Zval.native.asUnchecked(entry_obj.enumCaseValue().?, .int);
        ret.set(.int, name, value);
    }
}

fn map(ctx: phpz.Ctx) !void {
    var arr_zv: *c.zval = undefined;
    var cb: phpz.zend.Callable = undefined;
    try ctx.call.parse("af", .{ &arr_zv, &cb.fci, &cb.fcc });

    var result = phpz.Zval.Array.empty(ctx.ret.ptr());
    const ht = Zval.native.asUnchecked(arr_zv, .array);
    var it = phpz.zend.Array.from(ht).iterator();
    while (it.next()) |entry| {
        var rv = Zval.native.undef;
        try cb.withRetval(&rv).call(.{entry.value.*});

        switch (entry.key) {
            .string => |s| result.set(.mixed, s, &rv),
            .int => |i| try result.setAt(.mixed, i, &rv),
        }
    }
}

comptime {
    phpz.function("hello", hello);
    phpz.function("greet", greet);
    phpz.function("MyPHPExt\\increment", increment);
    phpz.function("MyPHPExt\\findById", findById);
    phpz.function("MyPHPExt\\getDefaultUser", getDefaultUser);
    phpz.function("MyPHPExt\\listStatuses", listStatuses);
    phpz.function("MyPHPExt\\map", map);
}
