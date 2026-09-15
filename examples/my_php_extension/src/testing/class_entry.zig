const std = @import("std");
const phpz = @import("phpz");

pub fn checkConstantMetadata(_: phpz.Ctx) !void {
    const text = phpz.zend.Constant.find("readtest\\TEXT") orelse return error.ConstantNotFound;
    try std.testing.expectEqualStrings("ReadTest\\TEXT", text.name());
    try std.testing.expectEqual(@as(u32, phpz.c.PHP_USER_CONSTANT), text.moduleNumber());
    try std.testing.expect(text.flags() & phpz.c.CONST_PERSISTENT == 0);
    try std.testing.expect(phpz.zend.Constant.find("ReadTest\\TEXT") == null);
    try std.testing.expect(phpz.zend.Constant.find("readtest\\text") == null);

    const child = (try phpz.ClassEntry.lookup("ConstantChild", true)).?;
    const values = child.findConstant("VALUES") orelse return error.ConstantNotFound;
    try std.testing.expectEqualStrings("ConstantParent", values.declaringClass().name());
    try std.testing.expect(values.isPublic() and !values.isProtected() and !values.isPrivate());
    try std.testing.expect(child.findConstant("HIDDEN").?.isProtected());
    try std.testing.expect(values.declaringClass().findConstant("SECRET").?.isPrivate());
    try std.testing.expect(child.findConstant("MISSING") == null);
    const broken = (try phpz.ClassEntry.lookup("BrokenConstant", true)).?;
    try std.testing.expect(broken.findConstant("VALUE").?.ptr().value.u1.v.type == phpz.c.IS_CONSTANT_AST);

    try expectPhpException(phpz.zend.Constant.get("MISSING_CONSTANT", null, false));
    try expectPhpException(broken.constant("VALUE", true));

    try std.testing.expect((try phpz.zend.Constant.get("MISSING_CONSTANT", null, true)) == null);
    try std.testing.expect(!phpz.errors.hasException());
    try std.testing.expect((try child.constant("MISSING", true)) == null);
    try std.testing.expect(!phpz.errors.hasException());
}

fn expectPhpException(result: phpz.errors.Exception!?*phpz.Zval) !void {
    const pending = phpz.errors.hasException();
    // Clear the PHP exception before assertions so it cannot mask a test failure.
    phpz.errors.clearException();
    try std.testing.expectError(error.PhpException, result);
    try std.testing.expect(pending);
}

pub fn readConstant(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{ .{ .string = .{} }, .{ .bool = .{} } }, {});
    const value = (try phpz.zend.Constant.get(args[0], null, args[1])) orelse return error.ConstantNotFound;
    ctx.retval.set(.mixed, value.ptr());
}

pub fn readClassConstant(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{ .{ .string = .{} }, .{ .string = .{} }, .{ .bool = .{} } }, {});
    const entry = (try phpz.ClassEntry.lookup(args[0], true)) orelse return error.ClassNotFound;
    const value = (try entry.constant(args[1], args[2])) orelse return error.ConstantNotFound;
    ctx.retval.set(.mixed, value.ptr());
}

pub fn lookupClass(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
        .{ .bool = .{} },
    }, {});
    if (try phpz.ClassEntry.lookup(args[0], args[1])) |entry| {
        ctx.retval.set(.string, entry.name());
    } else {
        ctx.retval.set(.null, {});
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
    ctx.retval.set(.mixed, value.ptr());
}
