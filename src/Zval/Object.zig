const Object = @This();

inner: *c.zval,

pub const Error = error{
    NullPointer,
    InitFailed,
} || Zval.Error;
pub fn from(zv: *c.zval) Error!Object {
    if (Zval.phpType(zv) != c.IS_OBJECT) return Error.TypeMismatch;
    if (zv.value.obj == null) return Error.NullPointer;
    return .{ .inner = zv };
}

pub fn init(zv: *c.zval) Object {
    c.object_init(zv);
    return .{ .inner = zv };
}

pub fn initClass(zv: *c.zval, ce: *c.zend_class_entry) Error!Object {
    const result = c.object_init_ex(zv, ce);
    if (result != c.SUCCESS) return Error.InitFailed;
    return .{ .inner = zv };
}

pub fn initClassWithConstructor(
    zv: *c.zval,
    class_type: *c.zend_class_entry,
    params: []c.zval,
    named_params: ?*c.zend_array,
) Error!Object {
    const result = c.object_init_with_constructor(
        zv,
        class_type,
        @intCast(params.len),
        params.ptr,
        named_params,
    );
    if (result != c.SUCCESS) return Error.InitFailed;
    return .{ .inner = zv };
}

/// Create an object with class and properties
pub fn initClassWithProperties(
    zv: *c.zval,
    ce: *c.zend_class_entry,
    properties: ?*c.zend_array,
) Error!Object {
    const result = c.object_and_properties_init(zv, ce, properties);
    if (result != c.SUCCESS) return Error.InitFailed;
    return .{ .inner = zv };
}

pub fn ptr(self: *Object) *c.zend_object {
    return self.inner.value.obj;
}

pub fn class(self: *Object) *c.zend_class_entry {
    return self.ptr().*.ce;
}

pub fn className(self: *Object) []const u8 {
    const ce = self.class();
    const name = ce.*.name;
    return @as([*]const u8, @ptrCast(&name.*.val))[0..name.*.len];
}

pub fn call(self: *Object, method: []const u8, args: []c.zval, retval: *c.zval) !void {
    const method_str: zend.String = .init(method);
    const result = c.zend_call_method_if_exists(
        self.ptr(),
        method_str.inner,
        retval,
        @intCast(args.len),
        if (args.len > 0) args.ptr else null,
    );
    if (result != c.SUCCESS) {
        c.zend_throw_error(null, "Call to undefined method %s::%s()", self.className().ptr, method_str.ptr());
        return error.CallFailed;
    }
}

pub fn set(self: *Object, comptime zk: Zval.Kind, key: []const u8, val: Zval.Type(zk)) void {
    switch (zk) {
        .null => c.add_property_null_ex(self.inner, key.ptr, key.len),
        .int => c.add_property_long_ex(self.inner, key.ptr, key.len, @intCast(val)),
        .float => c.add_property_double_ex(self.inner, key.ptr, key.len, val),
        .string => c.add_property_stringl_ex(self.inner, key.ptr, key.len, val.ptr, val.len),
        .bool => c.add_property_bool_ex(self.inner, key.ptr, key.len, val),
        .array => c.add_property_array_ex(self.inner, key.ptr, key.len, val),
        .object => c.add_property_object_ex(self.inner, key.ptr, key.len, val),
        .resource => c.add_property_resource_ex(self.inner, key.ptr, key.len, val),
        .reference => c.add_property_reference_ex(self.inner, key.ptr, key.len, val),
        .mixed => c.add_property_zval_ex(self.inner, key.ptr, key.len, val),
        .undef => @compileError("'undef' represents an uninitialized value and cannot be set as object property"),
    }
}

pub fn toZval(self: *Object) Zval {
    return .from(self.inner);
}

const c = @import("../root.zig").c;
const zend = @import("../zend.zig");
const Zval = @import("../Zval.zig");
