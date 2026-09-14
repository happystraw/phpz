const phpz = @import("phpz");

pub fn lookupClass(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
        .{ .bool = .{} },
    }, {});
    if (try phpz.ClassEntry.lookup(args[0], args[1])) |entry| {
        ctx.ret.set(.string, entry.name());
    } else {
        ctx.ret.set(.null, {});
    }
}

/// Return a copy of the property value; the example reports missing and
/// uninitialized slots as errors instead of exposing them as PHP values.
pub fn readStaticProperty(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
        .{ .string = .{} },
        .{ .bool = .{} },
    }, {});
    const entry = (try phpz.ClassEntry.lookup(args[0], true)) orelse return error.ClassNotFound;
    const value = (try entry.staticProperty(args[1], args[2])) orelse return error.PropertyNotFound;
    if (value.is(.undef)) return error.UninitializedProperty;
    ctx.ret.set(.mixed, value.ptr());
}
