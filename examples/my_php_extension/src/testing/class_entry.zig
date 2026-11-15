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

    // Property metadata names are unmangled for every visibility, including
    // inherited entries. The slice is also safe to use as a C string.
    const Scope = phpz.zend.property_name.Unmangled.Scope;
    inline for (.{
        .{ "visible", "visible", @as(Scope, .public) },
        .{ "\x00*\x00hidden", "hidden", @as(Scope, .protected) },
        .{ "\x00ConstantParent\x00secret", "secret", @as(Scope, .{ .private = "ConstantParent" }) },
        .{ "\x00class@anonymous\x00file.php:1$0\x00secret", "secret", @as(Scope, .{ .private = "class@anonymous\x00file.php:1$0" }) },
    }) |case| {
        const key = phpz.zend.String.init(case[0], false);
        defer key.release();
        const property = phpz.zend.property_name.unmangle(key) orelse return error.InvalidPropertyName;
        try std.testing.expectEqualStrings(case[1], property.name);
        try std.testing.expectEqualStrings(case[1], phpz.zend.property_name.unmangleName(key).?);
        inline for (.{ false, true }) |persistent| {
            const encoded = phpz.zend.property_name.mangle(property, persistent);
            defer encoded.release();
            try std.testing.expectEqualStrings(case[0], encoded.slice());
        }
        try std.testing.expectEqual(std.meta.activeTag(case[2]), std.meta.activeTag(property.scope));
        if (case[2] == .private) {
            try std.testing.expectEqualStrings(case[2].private, property.scope.private);
        }
    }
    const parent = values.declaringClass();
    inline for (.{ "visible", "hidden", "secret" }) |name| {
        const property = parent.findPropertyInfo(name) orelse return error.PropertyNotFound;
        try std.testing.expectEqualStrings(name, property.name());
        try std.testing.expectEqualStrings(name, std.mem.span(property.name().ptr));
        try std.testing.expectEqualStrings("ConstantParent", property.declaringClass().name());
    }
    try std.testing.expect(parent.findPropertyInfo("visible").?.isPublic());
    try std.testing.expect(parent.findPropertyInfo("hidden").?.isProtected());
    try std.testing.expect(parent.findPropertyInfo("secret").?.isPrivate());
    try std.testing.expectEqualStrings("visible", parent.findPropertyInfo("visible").?.rawName().slice());
    try std.testing.expectEqualStrings("\x00*\x00hidden", parent.findPropertyInfo("hidden").?.rawName().slice());
    const secret = parent.findPropertyInfo("secret").?;
    try std.testing.expectEqualStrings("\x00ConstantParent\x00secret", secret.rawName().slice());
    const decoded = phpz.zend.property_name.unmangle(secret.rawName()) orelse return error.InvalidPropertyName;
    try std.testing.expectEqualStrings(secret.name(), decoded.name);
    try std.testing.expect(decoded.scope == .private);
    try std.testing.expectEqualStrings("ConstantParent", decoded.scope.private);
    const inherited = child.findPropertyInfo("hidden") orelse return error.PropertyNotFound;
    try std.testing.expectEqualStrings("hidden", inherited.name());
    try std.testing.expectEqualStrings("ConstantParent", inherited.declaringClass().name());
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
