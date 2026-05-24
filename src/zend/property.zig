const c = @import("../root.zig").c;
const ClassEntry = @import("class_entry.zig").ClassEntry;
const Array = @import("array.zig").Array;

pub const Property = opaque {
    pub const Error = error{
        NotFound,
    };

    /// Wrap a zend_property_info pointer
    pub inline fn from(info: *c.zend_property_info) *Property {
        return @ptrCast(info);
    }

    /// Get the underlying zend_property_info pointer
    pub inline fn ptr(self: *Property) *c.zend_property_info {
        return @ptrCast(@alignCast(self));
    }

    /// Find a property by name from a class entry's properties_info HashTable.
    ///
    /// Searches only this class's own property declarations (not inherited).
    /// Returns null if the property is not declared by this class.
    pub fn find(ce: *ClassEntry, prop_name: []const u8) ?*Property {
        const info = c.zend_hash_str_find_ptr(&ce.ptr().*.properties_info, prop_name.ptr, prop_name.len);
        return if (info != null) .from(@ptrCast(@alignCast(info))) else null;
    }

    /// Get the property name as a byte slice
    pub fn name(self: *Property) []const u8 {
        const n = self.ptr().name;
        return n.*.val()[0..n.*.len];
    }

    /// Get the declaring class entry.
    ///
    /// For private properties inherited from parent classes, this points
    /// to the parent class where the property was originally declared.
    pub inline fn declaringClass(self: *Property) *ClassEntry {
        return ClassEntry.from(self.ptr().ce);
    }

    /// Get the property offset in the object structure
    pub inline fn offset(self: *Property) u32 {
        return @intCast(self.ptr().offset);
    }

    /// Get the raw property flags
    pub inline fn flags(self: *Property) u32 {
        return @intCast(self.ptr().flags);
    }

    /// Check if the property is public
    pub fn isPublic(self: *Property) bool {
        return (self.flags() & c.ZEND_ACC_PUBLIC) != 0;
    }

    /// Check if the property is protected
    pub fn isProtected(self: *Property) bool {
        return (self.flags() & c.ZEND_ACC_PROTECTED) != 0;
    }

    /// Check if the property is private
    pub fn isPrivate(self: *Property) bool {
        return (self.flags() & c.ZEND_ACC_PRIVATE) != 0;
    }

    /// Check if the property is static
    pub fn isStatic(self: *Property) bool {
        return (self.flags() & c.ZEND_ACC_STATIC) != 0;
    }

    /// Create an iterator over a class's own declared properties.
    pub fn iterator(ce: *ClassEntry) Array.PtrValueIterator(Property) {
        return .init(.from(&ce.ptr().*.properties_info));
    }
};

test {
    @import("std").testing.refAllDecls(Property);
}
