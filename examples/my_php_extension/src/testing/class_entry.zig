const std = @import("std");
const phpz = @import("phpz");

pub fn checkConstantMetadata() !void {
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
    try std.testing.expect(!phpz.exception.hasPending());
    try std.testing.expect((try child.constant("MISSING", true)) == null);
    try std.testing.expect(!phpz.exception.hasPending());
}

fn expectPhpException(result: phpz.exception.Error!?*phpz.Zval) !void {
    const pending = phpz.exception.hasPending();
    // Clear the PHP exception before assertions so it cannot mask a test failure.
    phpz.exception.clear();
    try std.testing.expectError(error.PhpException, result);
    try std.testing.expect(pending);
}

pub fn readConstant(name: []const u8, silent: bool) !*phpz.Zval {
    return (try phpz.zend.Constant.get(name, null, silent)) orelse error.ConstantNotFound;
}

pub fn readClassConstant(class_name: []const u8, name: []const u8, silent: bool) !*phpz.Zval {
    const entry = (try phpz.ClassEntry.lookup(class_name, true)) orelse return error.ClassNotFound;
    return (try entry.constant(name, silent)) orelse error.ConstantNotFound;
}

pub fn enumCase(class_name: []const u8, case_name: [:0]const u8) !?*phpz.zend.Object {
    const entry = (try phpz.ClassEntry.lookup(class_name, true)) orelse return error.ClassNotFound;
    const case = entry.getEnumCase(case_name) orelse return null;
    case.addref();
    return case;
}

pub fn lookupClass(name: []const u8, autoload: bool) !?[]const u8 {
    const entry = (try phpz.ClassEntry.lookup(name, autoload)) orelse return null;
    return entry.name();
}

/// Return a copy of the property value; the example reports missing and
/// uninitialized slots as errors instead of exposing them as PHP values.
pub fn readStaticProperty(class_name: []const u8, name: []const u8, silent: bool) !*phpz.Zval {
    const entry = (try phpz.ClassEntry.lookup(class_name, true)) orelse return error.ClassNotFound;
    const value = (try entry.staticProperty(name, silent)) orelse return error.PropertyNotFound;
    if (value.is(.undef)) return error.UninitializedProperty;
    return value;
}
