const phpz = @import("phpz");

pub fn initObject(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{.{ .string = .{} }}, {});
    const entry = (try phpz.ClassEntry.lookup(args[0], true)) orelse return error.ClassNotFound;
    ctx.ret.set(.object, try phpz.zend.Object.init(entry));
}

pub fn cloneObject(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{.{ .object = .{} }}, {});
    ctx.ret.set(.object, try args[0].clone());
}

pub fn constructObject(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
        .{ .array = .{} },
        .{ .bool = .{} },
    }, {});
    const entry = (try phpz.ClassEntry.lookup(args[0], true)) orelse return error.ClassNotFound;
    const obj = if (args[2])
        try phpz.zend.Object.tryNew(entry, .{}, args[1])
    else
        try phpz.zend.Object.new(entry, .{}, args[1]);
    ctx.ret.set(.object, obj);
}
