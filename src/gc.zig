const c = @import("c.zig").c;
const zend = @import("zend.zig");
const Zval = @import("zval.zig").Zval;

pub const GcBuffer = opaque {
    pub inline fn create() *GcBuffer {
        return .from(c.zend_get_gc_buffer_create());
    }

    pub inline fn from(buffer: *c.zend_get_gc_buffer) *GcBuffer {
        return @ptrCast(buffer);
    }

    pub inline fn ptr(self: *GcBuffer) *c.zend_get_gc_buffer {
        return @ptrCast(@alignCast(self));
    }

    pub fn use(self: *GcBuffer, table: *?[*]c.zval, n: *c_int) void {
        c.zend_get_gc_buffer_use(self.ptr(), table, n);
    }

    /// Reports an owned value for cycle collection. Skips non-refcounted values
    /// (null, bool, int, float).
    pub fn add(self: *GcBuffer, value: *Zval) void {
        c.zend_get_gc_buffer_add_zval(self.ptr(), value.ptr());
    }

    /// Reports an owned object for cycle collection. `value` must not be null.
    pub fn addObject(self: *GcBuffer, value: *zend.Object) void {
        c.zend_get_gc_buffer_add_obj(self.ptr(), value.ptr());
    }

    /// Reports an owned array for cycle collection. Skips immutable arrays; PHP 8.5+
    /// checks that in `zend_get_gc_buffer_add_ht`, older versions check here.
    pub fn addArray(self: *GcBuffer, value: *zend.Array) void {
        if (comptime @hasDecl(c, "zend_get_gc_buffer_add_ht")) {
            c.zend_get_gc_buffer_add_ht(self.ptr(), value.ptr());
        } else {
            if (value.isImmutable()) return;
            var array = Zval.raw.init(.array, value);
            self.add(.from(&array));
        }
    }

    /// Reports an owned callable for cycle collection: the function name and the
    /// bound object that `Callable.addref()` retains. Skips `Callable.nil`.
    pub fn addCallable(self: *GcBuffer, value: *zend.Callable) void {
        if (value.fci.size == 0) return;
        self.add(.from(&value.fci.function_name));
        if (value.fcc.object) |object| self.addObject(.from(object));
    }
};

test {
    @import("std").testing.refAllDecls(GcBuffer);
}
