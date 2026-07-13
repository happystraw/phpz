const c = @import("../root.zig").c;
const zend = @import("../zend.zig");
const Zval = @import("../zval.zig").Zval;

pub const Array = opaque {
    /// Create an empty array in caller-provided zval storage.
    ///
    /// Ownership: caller owns `zv`'s array value; call `Zval.raw.dtor(zv)`
    /// unless the zval is returned/transferred to PHP. The returned wrapper is
    /// borrowed from `zv`.
    pub fn empty(zv: *c.zval) *Array {
        zv.value.arr = c.zend_new_array(0);
        zv.u1.type_info = c.IS_ARRAY_EX;
        return @ptrCast(zv);
    }

    /// Create an array with initial capacity in caller-provided zval storage.
    ///
    /// Ownership: caller owns `zv`'s array value; call `Zval.raw.dtor(zv)`
    /// unless the zval is returned/transferred to PHP. The returned wrapper is
    /// borrowed from `zv`.
    pub fn init(zv: *c.zval, capacity: u32) *Array {
        zv.value.arr = c.zend_new_array(capacity);
        zv.u1.type_info = c.IS_ARRAY_EX;
        return @ptrCast(zv);
    }

    pub const FromError = error{NullPointer} || Zval.Error;

    /// Create from an existing zval pointer (must be array type).
    ///
    /// Ownership: borrowed wrapper; no refcount change.
    pub fn from(zv: *c.zval) FromError!*Array {
        if (Zval.raw.getType(zv) != c.IS_ARRAY) return error.TypeMismatch;
        if (zv.value.arr == null) return error.NullPointer;
        return @ptrCast(zv);
    }

    /// Get the underlying zval pointer.
    ///
    /// Ownership: borrowed raw pointer.
    pub inline fn ptr(self: *Array) *c.zval {
        return @ptrCast(@alignCast(self));
    }

    /// Get the underlying zend.Array pointer.
    ///
    /// Ownership: borrowed array pointer owned by this zval.
    pub fn array(self: *Array) *zend.Array {
        return .from(self.ptr().value.arr);
    }

    /// Get the number of elements
    pub fn len(self: *Array) usize {
        return self.ptr().value.arr.*.nNumOfElements;
    }

    /// Set a value by string key.
    ///
    /// Ownership: scalar/string values are copied. Refcounted wrapper values
    /// (`.array`, `.object`, `.resource`, `.reference`) and `.mixed` zvals are
    /// transferred into the array; addref/copy first if the input is borrowed
    /// and must remain independently owned.
    pub fn set(self: *Array, comptime zk: Zval.Kind, key: []const u8, val: Zval.Type(zk)) void {
        switch (zk) {
            .null => c.add_assoc_null_ex(self.ptr(), key.ptr, key.len),
            .int => c.add_assoc_long_ex(self.ptr(), key.ptr, key.len, @intCast(val)),
            .float => c.add_assoc_double_ex(self.ptr(), key.ptr, key.len, val),
            .string => c.add_assoc_stringl_ex(self.ptr(), key.ptr, key.len, val.ptr, val.len),
            .bool => c.add_assoc_bool_ex(self.ptr(), key.ptr, key.len, val),
            .array => c.add_assoc_array_ex(self.ptr(), key.ptr, key.len, val.ptr()),
            .object => c.add_assoc_object_ex(self.ptr(), key.ptr, key.len, val.ptr()),
            .resource => c.add_assoc_resource_ex(self.ptr(), key.ptr, key.len, val.ptr()),
            .reference => c.add_assoc_reference_ex(self.ptr(), key.ptr, key.len, val.ptr()),
            .mixed => c.add_assoc_zval_ex(self.ptr(), key.ptr, key.len, val),
            inline .undef, .indirect, .ptr => @compileError("'" ++ @tagName(zk) ++ "' cannot be set as array value"),
        }
    }

    pub const SetAtError = error{SetIndexFailed};

    /// Set a value by index.
    ///
    /// Ownership: scalar/string values are copied. Refcounted wrapper values
    /// (`.array`, `.object`, `.resource`, `.reference`) and `.mixed` zvals are
    /// transferred into the array; addref/copy first if the input is borrowed
    /// and must remain independently owned.
    pub fn setAt(self: *Array, comptime zk: Zval.Kind, index: isize, val: Zval.Type(zk)) SetAtError!void {
        const idx: c.zend_ulong = @bitCast(index);
        switch (zk) {
            .null => c.add_index_null(self.ptr(), idx),
            .int => c.add_index_long(self.ptr(), idx, @intCast(val)),
            .float => c.add_index_double(self.ptr(), idx, val),
            .string => c.add_index_stringl(self.ptr(), idx, val.ptr, val.len),
            .bool => c.add_index_bool(self.ptr(), idx, val),
            .array => c.add_index_array(self.ptr(), idx, val.ptr()),
            .object => c.add_index_object(self.ptr(), idx, val.ptr()),
            .resource => c.add_index_resource(self.ptr(), idx, val.ptr()),
            .reference => c.add_index_reference(self.ptr(), idx, val.ptr()),
            .mixed => {
                if (c.add_index_zval(self.ptr(), idx, val) != c.SUCCESS) return error.SetIndexFailed;
            },
            inline .undef, .indirect, .ptr => @compileError("'" ++ @tagName(zk) ++ "' cannot be set as array element"),
        }
    }

    pub const AppendError = error{AppendFailed};

    /// Append a value to the array.
    ///
    /// Ownership: scalar/string values are copied. Refcounted wrapper values
    /// (`.array`, `.object`, `.resource`, `.reference`) and `.mixed` zvals are
    /// transferred into the array; addref/copy first if the input is borrowed
    /// and must remain independently owned.
    pub fn append(self: *Array, comptime zk: Zval.Kind, val: Zval.Type(zk)) AppendError!void {
        const result = switch (zk) {
            .null => c.add_next_index_null(self.ptr()),
            .int => c.add_next_index_long(self.ptr(), @intCast(val)),
            .float => c.add_next_index_double(self.ptr(), val),
            .string => c.add_next_index_stringl(self.ptr(), val.ptr, val.len),
            .bool => c.add_next_index_bool(self.ptr(), val),
            .array => c.add_next_index_array(self.ptr(), val.ptr()),
            .object => c.add_next_index_object(self.ptr(), val.ptr()),
            .resource => c.add_next_index_resource(self.ptr(), val.ptr()),
            .reference => c.add_next_index_reference(self.ptr(), val.ptr()),
            .mixed => c.add_next_index_zval(self.ptr(), val),
            inline .undef, .indirect, .ptr => @compileError("'" ++ @tagName(zk) ++ "' cannot be appended to array"),
        };
        if (result != c.SUCCESS) return error.AppendFailed;
    }
};

test {
    @import("std").testing.refAllDecls(Array);
}
