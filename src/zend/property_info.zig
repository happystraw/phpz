const c = @import("../root.zig").c;
const ClassEntry = @import("class_entry.zig").ClassEntry;

pub const PropertyInfo = opaque {
    pub const Error = error{
        NotFound,
    };

    /// Wrap a zend_property_info pointer
    pub inline fn from(info: *c.zend_property_info) *PropertyInfo {
        return @ptrCast(info);
    }

    /// Get the underlying zend_property_info pointer
    pub inline fn ptr(self: *PropertyInfo) *c.zend_property_info {
        return @ptrCast(@alignCast(self));
    }

    /// Get the property name as a byte slice
    pub fn name(self: *PropertyInfo) [:0]const u8 {
        const n = self.ptr().name;
        return n.*.val()[0..n.*.len :0];
    }

    /// Get the declaring class entry.
    ///
    /// Inherited entries retain the class where the property was declared.
    pub inline fn declaringClass(self: *PropertyInfo) *ClassEntry {
        return ClassEntry.from(self.ptr().ce);
    }

    /// Get the property offset in the object structure
    pub inline fn offset(self: *PropertyInfo) u32 {
        return @intCast(self.ptr().offset);
    }

    /// Get the raw property flags
    pub inline fn flags(self: *PropertyInfo) u32 {
        return @intCast(self.ptr().flags);
    }

    /// Check if the property is public
    pub fn isPublic(self: *PropertyInfo) bool {
        return (self.flags() & c.ZEND_ACC_PUBLIC) != 0;
    }

    /// Check if the property is protected
    pub fn isProtected(self: *PropertyInfo) bool {
        return (self.flags() & c.ZEND_ACC_PROTECTED) != 0;
    }

    /// Check if the property is private
    pub fn isPrivate(self: *PropertyInfo) bool {
        return (self.flags() & c.ZEND_ACC_PRIVATE) != 0;
    }

    /// Check if the property is static
    pub fn isStatic(self: *PropertyInfo) bool {
        return (self.flags() & c.ZEND_ACC_STATIC) != 0;
    }
};

test {
    @import("std").testing.refAllDecls(PropertyInfo);
}
