const phpz = @import("phpz");

pub fn objectProperties(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{ .{ .object = .{} }, .{ .bool = .{} } }, {});
    const props = if (args[1]) try args[0].stdProperties() else try args[0].properties();
    ctx.retval.set(.array, if (props) |table| table.dupe() else phpz.zend.Array.empty());
}

pub fn hasObjectProperty(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{ .{ .object = .{} }, .{ .string = .{} }, .{ .bool = .{} } }, {});
    ctx.retval.set(.bool, if (args[2])
        try args[0].hasStdProperty(args[1], .isset)
    else
        try args[0].hasProperty(args[1], .isset));
}

pub fn initObject(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{.{ .string = .{} }}, {});
    const entry = (try phpz.ClassEntry.lookup(args[0], true)) orelse return error.ClassNotFound;
    ctx.retval.set(.object, try phpz.zend.Object.init(entry));
}

pub fn cloneObject(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{.{ .object = .{} }}, {});
    ctx.retval.set(.object, try args[0].clone());
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
    ctx.retval.set(.object, obj);
}
