const c = @import("../root.zig").c;

pub const Resource = opaque {
    /// Create from an existing zend_resource pointer
    pub inline fn from(res: *c.zend_resource) *Resource {
        return @ptrCast(res);
    }

    /// Get the underlying zend_resource pointer
    pub inline fn ptr(self: *Resource) *c.zend_resource {
        return @ptrCast(@alignCast(self));
    }

    /// Get the resource handle (registered resource ID)
    pub inline fn handle(self: *Resource) i64 {
        return @intCast(self.ptr().handle);
    }

    /// Get the resource type ID
    pub inline fn @"type"(self: *Resource) c_int {
        return self.ptr().type;
    }

    /// Get the opaque user pointer
    pub inline fn userPtr(self: *Resource) ?*anyopaque {
        return self.ptr().ptr;
    }

    /// Get refcount
    pub inline fn refcount(self: *Resource) u32 {
        return c.zend_gc_refcount(&self.ptr().gc);
    }

    /// Increment refcount
    pub fn addref(self: *Resource) void {
        _ = c.zend_gc_addref(&self.ptr().gc);
    }

    /// Decrement refcount
    pub fn delref(self: *Resource) void {
        _ = c.zend_gc_delref(&self.ptr().gc);
    }
};

test {
    @import("std").testing.refAllDecls(Resource);
}
