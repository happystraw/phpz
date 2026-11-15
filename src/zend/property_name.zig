const std = @import("std");
const c = @import("../root.zig").c;
const String = @import("string.zig").String;

pub const Unmangled = struct {
    name: [:0]const u8,
    scope: Scope,

    pub const Scope = union(enum) {
        public,
        protected,
        /// Declaring class name; anonymous class names may contain NULs.
        private: [:0]const u8,
    };
};

/// Encode an object property name and its scope using Zend's mangling rules.
/// Public names are copied without a scope prefix. Private scopes must be valid
/// declaring class names; anonymous class names may contain embedded NULs.
/// Ownership: caller owns the returned string; call release() when done.
pub fn mangle(property: Unmangled, persistent: bool) *String {
    const scope: [:0]const u8 = switch (property.scope) {
        .public => return .init(property.name, persistent),
        .protected => "*",
        .private => |class| class,
    };
    return .from(c.zend_mangle_property_name(
        scope.ptr,
        scope.len,
        property.name.ptr,
        property.name.len,
        persistent,
    ));
}

/// Unmangle an object property key using Zend's property-name rules.
/// Ownership: both slices borrow raw, which must remain alive.
/// Malformed names return null; Zend also emits a notice in that case.
pub fn unmangle(raw: *String) ?Unmangled {
    var class_name: [*c]const u8 = undefined;
    var prop_name: [*c]const u8 = undefined;
    var prop_len: usize = undefined;
    if (c.zend_unmangle_property_name_ex(raw.ptr(), &class_name, &prop_name, &prop_len) != c.SUCCESS) return null;
    const scope: Unmangled.Scope = if (class_name != null) blk: {
        const class = class_name[0 .. @intFromPtr(prop_name) - @intFromPtr(class_name) - 1 :0];
        break :blk if (std.mem.eql(u8, class, "*")) .protected else .{ .private = class };
    } else .public;
    return .{
        .name = prop_name[0..prop_len :0],
        .scope = scope,
    };
}

/// Get only the unmangled property name, borrowing raw.
/// Malformed names return null; Zend also emits a notice in that case.
pub fn unmangleName(raw: *String) ?[:0]const u8 {
    return if (unmangle(raw)) |property| property.name else null;
}

test {
    std.testing.refAllDecls(@This());
}
