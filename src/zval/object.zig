const c = @import("../root.zig").c;
const zend = @import("../zend.zig");
const Zval = @import("../zval.zig").Zval;

pub const Object = opaque {
    /// Create a standard object (stdClass)
    pub fn init(zv: *c.zval) *Object {
        c.object_init(zv);
        return @ptrCast(zv);
    }

    pub const InitClassError = error{InitFailed};

    /// Create an object from a class entry
    pub fn initClass(zv: *c.zval, ce: *zend.ClassEntry) InitClassError!*Object {
        const result = c.object_init_ex(zv, ce.ptr());
        if (result != c.SUCCESS) return error.InitFailed;
        return @ptrCast(zv);
    }

    /// Create an object with class and properties
    pub fn initClassWithProperties(
        zv: *c.zval,
        ce: *zend.ClassEntry,
        properties: ?*c.zend_array,
    ) InitClassError!*Object {
        const result = c.object_and_properties_init(zv, ce.ptr(), properties);
        if (result != c.SUCCESS) return error.InitFailed;
        return @ptrCast(zv);
    }

    pub const FromError = error{NullPointer} || Zval.Error;

    /// Create from an existing zval pointer (must be object type)
    pub fn from(zv: *c.zval) FromError!*Object {
        if (Zval.native.getType(zv) != c.IS_OBJECT) return error.TypeMismatch;
        if (zv.value.obj == null) return error.NullPointer;
        return @ptrCast(zv);
    }

    /// Get the underlying zval pointer
    pub inline fn ptr(self: *Object) *c.zval {
        return @ptrCast(@alignCast(self));
    }

    /// Get the underlying zend.Object pointer
    pub fn object(self: *Object) *zend.Object {
        return .from(self.ptr().value.obj);
    }

    /// Get the class entry
    pub fn class(self: *Object) *zend.ClassEntry {
        return self.object().class();
    }

    /// Set a property value
    pub fn set(self: *Object, comptime zk: Zval.Kind, key: []const u8, val: Zval.Type(zk)) void {
        switch (zk) {
            .null => c.add_property_null_ex(self.ptr(), key.ptr, key.len),
            .int => c.add_property_long_ex(self.ptr(), key.ptr, key.len, @intCast(val)),
            .float => c.add_property_double_ex(self.ptr(), key.ptr, key.len, val),
            .string => c.add_property_stringl_ex(self.ptr(), key.ptr, key.len, val.ptr, val.len),
            .bool => c.add_property_bool_ex(self.ptr(), key.ptr, key.len, val),
            .array => c.add_property_array_ex(self.ptr(), key.ptr, key.len, val.ptr()),
            .object => c.add_property_object_ex(self.ptr(), key.ptr, key.len, val.ptr()),
            .resource => c.add_property_resource_ex(self.ptr(), key.ptr, key.len, val.ptr()),
            .reference => c.add_property_reference_ex(self.ptr(), key.ptr, key.len, val.ptr()),
            .mixed => c.add_property_zval_ex(self.ptr(), key.ptr, key.len, val),
            inline .undef, .indirect, .ptr => @compileError("'" ++ @tagName(zk) ++ "' cannot be set as object property"),
        }
    }
};

test {
    @import("std").testing.refAllDecls(Object);
}
