const c = @import("../root.zig").c;

pub const Reference = opaque {
    /// Create from an existing zend_reference pointer
    pub inline fn from(ref: *c.zend_reference) *Reference {
        return @ptrCast(ref);
    }

    /// Get the underlying zend_reference pointer
    pub inline fn ptr(self: *Reference) *c.zend_reference {
        return @ptrCast(@alignCast(self));
    }

    /// Get the referenced value as a raw zval pointer
    pub inline fn val(self: *Reference) *c.zval {
        return &self.ptr().val;
    }

    /// Get refcount
    pub inline fn refcount(self: *Reference) u32 {
        return c.zend_gc_refcount(&self.ptr().gc);
    }

    /// Increment refcount
    pub fn addref(self: *Reference) void {
        _ = c.zend_gc_addref(&self.ptr().gc);
    }

    /// Decrement refcount
    pub fn delref(self: *Reference) void {
        _ = c.zend_gc_delref(&self.ptr().gc);
    }
};

test {
    @import("std").testing.refAllDecls(Reference);
}
