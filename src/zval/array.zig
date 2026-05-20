const c = @import("../root.zig").c;
const zend = @import("../zend.zig");
const Zval = @import("../zval.zig").Zval;

pub const Array = opaque {
    pub const Error = error{
        NullPointer,
        SetIndexFailed,
        AppendFailed,
    } || Zval.Error;

    /// Create an empty array
    pub fn empty(zv: *c.zval) *Array {
        zv.value.arr = c.zend_new_array(0);
        zv.u1.type_info = c.IS_ARRAY_EX;
        return @ptrCast(zv);
    }

    /// Create an array with initial capacity
    pub fn init(zv: *c.zval, capacity: u32) *Array {
        zv.value.arr = c.zend_new_array(capacity);
        zv.u1.type_info = c.IS_ARRAY_EX;
        return @ptrCast(zv);
    }

    /// Create from an existing zval pointer (must be array type)
    pub fn from(zv: *c.zval) Error!*Array {
        if (Zval.native.getType(zv) != c.IS_ARRAY) return Error.TypeMismatch;
        if (zv.value.arr == null) return Error.NullPointer;
        return @ptrCast(zv);
    }

    /// Get the underlying zval pointer
    pub inline fn ptr(self: *Array) *c.zval {
        return @ptrCast(@alignCast(self));
    }

    /// Get the underlying zend.Array pointer
    pub fn array(self: *Array) *zend.Array {
        return .from(self.ptr().value.arr);
    }

    /// Get the number of elements
    pub fn len(self: *Array) usize {
        return self.ptr().value.arr.*.nNumOfElements;
    }

    /// Set a value by string key
    pub fn set(self: *Array, comptime zk: Zval.Kind, key: []const u8, val: Zval.Type(zk)) void {
        switch (zk) {
            .null => c.add_assoc_null_ex(self.ptr(), key.ptr, key.len),
            .int => c.add_assoc_long_ex(self.ptr(), key.ptr, key.len, @intCast(val)),
            .float => c.add_assoc_double_ex(self.ptr(), key.ptr, key.len, val),
            .string => c.add_assoc_stringl_ex(self.ptr(), key.ptr, key.len, val.ptr, val.len),
            .bool => c.add_assoc_bool_ex(self.ptr(), key.ptr, key.len, val),
            .array => c.add_assoc_array_ex(self.ptr(), key.ptr, key.len, val),
            .object => c.add_assoc_object_ex(self.ptr(), key.ptr, key.len, val),
            .resource => c.add_assoc_resource_ex(self.ptr(), key.ptr, key.len, val),
            .reference => c.add_assoc_reference_ex(self.ptr(), key.ptr, key.len, val),
            .mixed => c.add_assoc_zval_ex(self.ptr(), key.ptr, key.len, val),
            .undef => @compileError("'undef' represents an uninitialized value and cannot be set as array value"),
        }
    }

    /// Set a value by index
    pub fn setAt(self: *Array, comptime zk: Zval.Kind, index: isize, val: Zval.Type(zk)) Error!void {
        const idx: c.zend_ulong = @bitCast(index);
        switch (zk) {
            .null => c.add_index_null(self.ptr(), idx),
            .int => c.add_index_long(self.ptr(), idx, @intCast(val)),
            .float => c.add_index_double(self.ptr(), idx, val),
            .string => c.add_index_stringl(self.ptr(), idx, val.ptr, val.len),
            .bool => c.add_index_bool(self.ptr(), idx, val),
            .array => c.add_index_array(self.ptr(), idx, val),
            .object => c.add_index_object(self.ptr(), idx, val),
            .resource => c.add_index_resource(self.ptr(), idx, val),
            .reference => c.add_index_reference(self.ptr(), idx, val),
            .mixed => {
                if (c.add_index_zval(self.ptr(), idx, val) != c.SUCCESS) return Error.SetIndexFailed;
            },
            .undef => @compileError("'undef' represents an uninitialized value and cannot be set as array element"),
        }
    }

    /// Append a value to the array
    pub fn append(self: *Array, comptime zk: Zval.Kind, val: Zval.Type(zk)) Error!void {
        const result = switch (zk) {
            .null => c.add_next_index_null(self.ptr()),
            .int => c.add_next_index_long(self.ptr(), @intCast(val)),
            .float => c.add_next_index_double(self.ptr(), val),
            .string => c.add_next_index_stringl(self.ptr(), val.ptr, val.len),
            .bool => c.add_next_index_bool(self.ptr(), val),
            .array => c.add_next_index_array(self.ptr(), val),
            .object => c.add_next_index_object(self.ptr(), val),
            .resource => c.add_next_index_resource(self.ptr(), val),
            .reference => c.add_next_index_reference(self.ptr(), val),
            .mixed => c.add_next_index_zval(self.ptr(), val),
            .undef => @compileError("'undef' represents an uninitialized value and cannot be appended"),
        };
        if (result != c.SUCCESS) return Error.AppendFailed;
    }
};

test {
    @import("std").testing.refAllDecls(Array);
}
