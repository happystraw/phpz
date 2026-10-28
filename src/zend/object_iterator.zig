const c = @import("../root.zig").c;
const exception = @import("../exception.zig");
const Zval = @import("../zval.zig").Zval;
const Object = @import("object.zig").Object;

pub const ObjectIterator = opaque {
    pub const InitError = error{IteratorCreationFailed} || exception.Error;

    /// Acquire and rewind a Traversable object's iterator.
    /// Zend checks whether by-reference iteration is supported.
    /// Ownership: caller owns the iterator and must release it.
    /// PHP exceptions release partially initialized iterators; bailouts propagate.
    pub fn init(object: *Object, by_ref: bool) InitError!*ObjectIterator {
        const ce = object.class().ptr();
        const get_iterator = ce.*.get_iterator orelse
            return exception.typeError("Object of type %s is not traversable", .{object.class().name().ptr});
        var value = Zval.raw.init(.object, object);
        const iterator = get_iterator(ce, &value, @intFromBool(by_ref));
        if (exception.pending()) |err| {
            if (iterator) |iter| c.zend_iterator_dtor(iter);
            return exception.pending() orelse err;
        }
        const self = from(iterator orelse return error.IteratorCreationFailed);
        self.rewind() catch |err| {
            self.release();
            return exception.pending() orelse err;
        };
        return self;
    }

    /// Wrap an existing iterator without changing ownership or position.
    pub inline fn from(iterator: *c.zend_object_iterator) *ObjectIterator {
        return @ptrCast(iterator);
    }

    pub inline fn ptr(self: *ObjectIterator) *c.zend_object_iterator {
        return @ptrCast(@alignCast(self));
    }

    /// Release one owned iterator through Zend's iterator destructor.
    /// Destructors may leave a PHP exception pending.
    pub fn release(self: *ObjectIterator) void {
        c.zend_iterator_dtor(self.ptr());
    }

    /// Reset the fallback key index and invoke rewind when provided.
    pub fn rewind(self: *ObjectIterator) exception.Error!void {
        const iterator = self.ptr();
        iterator.index = 0;
        if (iterator.funcs.*.rewind) |callback| callback(iterator);
        try exception.check();
    }

    /// Check the current position, propagating exceptions even when valid returns FAILURE.
    pub fn valid(self: *ObjectIterator) exception.Error!bool {
        const iterator = self.ptr();
        const result = iterator.funcs.*.valid.?(iterator);
        try exception.check();
        return result == c.SUCCESS;
    }

    /// Borrow the current value, preserving reference wrappers; requires a valid position.
    /// Copy it before invoking other callbacks or releasing the iterator.
    pub fn current(self: *ObjectIterator) exception.Error!?*c.zval {
        const iterator = self.ptr();
        const value = iterator.funcs.*.get_current_data.?(iterator);
        try exception.check();
        return value;
    }

    /// Return an owned key at a valid position; release or transfer the returned value.
    /// Iterators without a key callback use an incrementing integer key.
    pub fn key(self: *ObjectIterator) exception.Error!c.zval {
        const iterator = self.ptr();
        var value = Zval.raw.undef;
        if (iterator.funcs.*.get_current_key) |callback| {
            callback(iterator, &value);
            if (exception.pending()) |err| {
                Zval.raw.release(&value);
                return exception.pending() orelse err;
            }
        } else {
            Zval.raw.set(&value, .int, @as(c.zend_long, @bitCast(iterator.index)));
        }
        return value;
    }

    /// Advance from a valid position, invalidating borrowed current values.
    pub fn advance(self: *ObjectIterator) exception.Error!void {
        const iterator = self.ptr();
        iterator.index +%= 1;
        iterator.funcs.*.move_forward.?(iterator);
        try exception.check();
    }
};

test {
    @import("std").testing.refAllDecls(ObjectIterator);
}
