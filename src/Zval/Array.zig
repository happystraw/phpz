const Array = @This();

inner: *c.zval,

pub const Error = error{
    NullPointer,
    SetIndexFailed,
    AppendFailed,
} || Zval.Error;

pub fn from(zv: *c.zval) Error!Array {
    if (Zval.phpType(zv) != c.IS_ARRAY) Error.TypeMismatch;
    if (zv.value.arr == null) return Error.NullPointer;
    return .{ .inner = zv };
}

pub fn empty(zv: *c.zval) Array {
    zv.value.arr = c.zend_new_array(0);
    zv.u1.type_info = c.IS_ARRAY_EX;
    return .{ .inner = zv };
}

pub fn init(zv: *c.zval, capacity: usize) Array {
    zv.value.arr = c.zend_new_array(@intCast(capacity));
    zv.u1.type_info = c.IS_ARRAY_EX;
    return .{ .inner = zv };
}

pub fn ptr(self: *Array) *c.zend_array {
    return self.inner.value.arr;
}

pub fn len(self: *Array) usize {
    return self.inner.value.arr.*.nNumOfElements;
}

pub fn set(self: *Array, comptime zk: Zval.Kind, key: []const u8, val: Zval.Type(zk)) void {
    switch (zk) {
        .null => c.add_assoc_null_ex(self.inner, key.ptr, key.len),
        .int => c.add_assoc_long_ex(self.inner, key.ptr, key.len, @intCast(val)),
        .float => c.add_assoc_double_ex(self.inner, key.ptr, key.len, val),
        .string => c.add_assoc_stringl_ex(self.inner, key.ptr, key.len, val.ptr, val.len),
        .bool => c.add_assoc_bool_ex(self.inner, key.ptr, key.len, val),
        .array => c.add_assoc_array_ex(self.inner, key.ptr, key.len, val),
        .object => c.add_assoc_object_ex(self.inner, key.ptr, key.len, val),
        .resource => c.add_assoc_resource_ex(self.inner, key.ptr, key.len, val),
        .reference => c.add_assoc_reference_ex(self.inner, key.ptr, key.len, val),
        .mixed => c.add_assoc_zval_ex(self.inner, key.ptr, key.len, val),
        .undef => @compileError("'undef' represents an uninitialized value and cannot be set as array value"),
    }
}

pub fn setAt(self: *Array, comptime zk: Zval.Kind, index: usize, val: Zval.Type(zk)) Error!void {
    switch (zk) {
        .null => c.add_index_null(self.inner, @intCast(index)),
        .int => c.add_index_long(self.inner, @intCast(index), @intCast(val)),
        .float => c.add_index_double(self.inner, @intCast(index), val),
        .string => c.add_index_stringl(self.inner, @intCast(index), val.ptr, val.len),
        .bool => c.add_index_bool(self.inner, @intCast(index), val),
        .array => c.add_index_array(self.inner, @intCast(index), val),
        .object => c.add_index_object(self.inner, @intCast(index), val),
        .resource => c.add_index_resource(self.inner, @intCast(index), val),
        .reference => c.add_index_reference(self.inner, @intCast(index), val),
        .mixed => {
            if (c.add_index_zval(self.inner, @intCast(index), val) != c.SUCCESS) return Error.SetIndexFailed;
        },
        .undef => @compileError("'undef' represents an uninitialized value and cannot be set as array element"),
    }
}

pub fn append(self: *Array, comptime zk: Zval.Kind, val: Zval.Type(zk)) Error!void {
    const result = switch (zk) {
        .null => c.add_next_index_null(self.inner),
        .int => c.add_next_index_long(self.inner, @intCast(val)),
        .float => c.add_next_index_double(self.inner, val),
        .string => c.add_next_index_stringl(self.inner, val.ptr, val.len),
        .bool => c.add_next_index_bool(self.inner, val),
        .array => c.add_next_index_array(self.inner, val),
        .object => c.add_next_index_object(self.inner, val),
        .resource => c.add_next_index_resource(self.inner, val),
        .reference => c.add_next_index_reference(self.inner, val),
        .mixed => c.add_next_index_zval(self.inner, val),
        .undef => @compileError("'undef' represents an uninitialized value and cannot be appended"),
    };
    if (result != c.SUCCESS) return Error.AppendFailed;
}

pub fn toZval(self: *Array) Zval {
    return .from(self.inner);
}

const c = @import("../root.zig").c;
const Zval = @import("../Zval.zig");
