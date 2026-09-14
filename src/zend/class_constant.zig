const c = @import("../c.zig").c;
const ClassEntry = @import("class_entry.zig").ClassEntry;

pub const ClassConstant = opaque {
    pub inline fn from(raw: *c.zend_class_constant) *ClassConstant {
        return @ptrCast(raw);
    }

    pub inline fn ptr(self: *ClassConstant) *c.zend_class_constant {
        return @ptrCast(@alignCast(self));
    }

    /// Inherited entries retain the class where the constant was declared.
    pub inline fn declaringClass(self: *ClassConstant) *ClassEntry {
        return .from(self.ptr().ce);
    }

    pub inline fn flags(self: *ClassConstant) u32 {
        return c.ZEND_CLASS_CONST_FLAGS(self.ptr());
    }

    pub fn isPublic(self: *ClassConstant) bool {
        return (self.flags() & c.ZEND_ACC_PUBLIC) != 0;
    }

    pub fn isProtected(self: *ClassConstant) bool {
        return (self.flags() & c.ZEND_ACC_PROTECTED) != 0;
    }

    pub fn isPrivate(self: *ClassConstant) bool {
        return (self.flags() & c.ZEND_ACC_PRIVATE) != 0;
    }
};

test {
    @import("std").testing.refAllDecls(ClassConstant);
}
