const c = @import("../root.zig").c;
const zend = @import("../zend.zig");
const Zval = @import("../zval.zig").Zval;

pub const Object = opaque {
    pub const Error = error{
        NullPointer,
        InitFailed,
        CallFailed,
    } || Zval.Error;

    /// Create a standard object (stdClass)
    pub fn init(zv: *c.zval) *Object {
        c.object_init(zv);
        return @ptrCast(zv);
    }

    /// Create an object from a class entry
    pub fn initClass(zv: *c.zval, ce: *c.zend_class_entry) Error!*Object {
        const result = c.object_init_ex(zv, ce);
        if (result != c.SUCCESS) return Error.InitFailed;
        return @ptrCast(zv);
    }

    /// Create an object with class and properties
    pub fn initClassWithProperties(
        zv: *c.zval,
        ce: *c.zend_class_entry,
        properties: ?*c.zend_array,
    ) Error!*Object {
        const result = c.object_and_properties_init(zv, ce, properties);
        if (result != c.SUCCESS) return Error.InitFailed;
        return @ptrCast(zv);
    }

    /// Create from an existing zval pointer (must be object type)
    pub fn from(zv: *c.zval) Error!*Object {
        if (Zval.native.getType(zv) != c.IS_OBJECT) return Error.TypeMismatch;
        if (zv.value.obj == null) return Error.NullPointer;
        return @ptrCast(zv);
    }

    /// Get the underlying zval pointer
    pub inline fn ptr(self: *Object) *c.zval {
        return @ptrCast(@alignCast(self));
    }

    /// Get the underlying zend_object pointer
    pub fn object(self: *Object) *c.zend_object {
        return self.ptr().value.obj;
    }

    /// Get the class entry
    pub fn class(self: *Object) *c.zend_class_entry {
        return self.object().*.ce;
    }

    /// Get the class name
    pub fn className(self: *Object) []const u8 {
        const ce = self.class();
        const name = ce.*.name;
        return name.*.val()[0..name.*.len];
    }

    /// Call a method on the object
    pub fn call(self: *Object, method: []const u8, args: []c.zval, retval: *c.zval) Error!void {
        const method_str: *zend.String = zend.String.init(method);
        const result = c.zend_call_method_if_exists(
            self.object(),
            method_str.ptr(),
            retval,
            @intCast(args.len),
            if (args.len > 0) args.ptr else null,
        );
        if (result != c.SUCCESS) {
            c.zend_throw_error(null, "Call to undefined method %s::%s()", self.className().ptr, method_str.cstr());
            return Error.CallFailed;
        }
    }

    /// Set a property value
    pub fn set(self: *Object, comptime zk: Zval.Kind, key: []const u8, val: Zval.Type(zk)) void {
        switch (zk) {
            .null => c.add_property_null_ex(self.ptr(), key.ptr, key.len),
            .int => c.add_property_long_ex(self.ptr(), key.ptr, key.len, @intCast(val)),
            .float => c.add_property_double_ex(self.ptr(), key.ptr, key.len, val),
            .string => c.add_property_stringl_ex(self.ptr(), key.ptr, key.len, val.ptr, val.len),
            .bool => c.add_property_bool_ex(self.ptr(), key.ptr, key.len, val),
            .array => c.add_property_array_ex(self.ptr(), key.ptr, key.len, val),
            .object => c.add_property_object_ex(self.ptr(), key.ptr, key.len, val),
            .resource => c.add_property_resource_ex(self.ptr(), key.ptr, key.len, val),
            .reference => c.add_property_reference_ex(self.ptr(), key.ptr, key.len, val),
            .mixed => c.add_property_zval_ex(self.ptr(), key.ptr, key.len, val),
            .undef => @compileError("'undef' represents an uninitialized value and cannot be set as object property"),
        }
    }
};

test {
    @import("std").testing.refAllDecls(Object);
}
