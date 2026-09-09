const c = @import("c.zig").c;
const zend = @import("zend.zig");
const Zval = @import("zval.zig").Zval;

/// Collector supplied to a class `.gc` callback.
pub const Gc = opaque {
    pub inline fn from(buffer: *c.zend_get_gc_buffer) *Gc {
        return @ptrCast(buffer);
    }

    pub inline fn ptr(self: *Gc) *c.zend_get_gc_buffer {
        return @ptrCast(@alignCast(self));
    }

    /// Report a PHP value owned by the backing. Does not change its reference count.
    /// Report each owned reference once; non-refcounted values are ignored.
    pub fn add(self: *Gc, value: *Zval) void {
        c.zend_get_gc_buffer_add_zval(self.ptr(), value.ptr());
    }

    /// Report an owned object reference without changing its reference count.
    pub fn addObject(self: *Gc, value: *zend.Object) void {
        c.zend_get_gc_buffer_add_obj(self.ptr(), value.ptr());
    }

    /// Report an owned array reference. Immutable arrays are ignored.
    pub fn addArray(self: *Gc, value: *zend.Array) void {
        if (comptime @hasDecl(c, "zend_get_gc_buffer_add_ht")) {
            c.zend_get_gc_buffer_add_ht(self.ptr(), value.ptr());
        } else {
            if (value.isImmutable()) return;
            var array = Zval.raw.init(.array, value);
            self.add(.from(&array));
        }
    }

    /// Report references retained by `Callable.addref()`. A nil callable is ignored.
    pub fn addCallable(self: *Gc, value: *zend.Callable) void {
        if (value.fci.size == 0) return;
        self.add(.from(&value.fci.function_name));
        if (value.fcc.object) |object| self.addObject(.from(object));
    }
};

test {
    @import("std").testing.refAllDecls(Gc);
}
