const errors = @import("../errors.zig");
const c = @import("../root.zig").c;
const native = @import("../zval.zig").Zval.native;
const Array = @import("array.zig").Array;
const ClassEntry = @import("class_entry.zig").ClassEntry;
const Function = @import("function.zig").Function;
const String = @import("string.zig").String;

pub const Object = opaque {
    pub const InitError = error{InitFailed};

    /// Create a standard object (stdClass)
    pub fn init() InitError!*Object {
        const obj = c.zend_objects_new(c.zend_standard_class_def);
        if (obj == null) return error.InitFailed;
        c.object_properties_init(obj, c.zend_standard_class_def);
        return @ptrCast(obj);
    }

    /// Create an object from a class entry
    pub fn initClass(ce: *ClassEntry) InitError!*Object {
        const obj = c.zend_objects_new(ce.ptr());
        if (obj == null) return error.InitFailed;
        c.object_properties_init(obj, ce.ptr());
        return @ptrCast(obj);
    }

    /// Create an object from an existing zend_object pointer
    pub inline fn from(obj: *c.zend_object) *Object {
        return @ptrCast(obj);
    }

    /// Get the underlying zend_object pointer
    pub inline fn ptr(self: *Object) *c.zend_object {
        return @ptrCast(@alignCast(self));
    }

    /// Release the object (decrement refcount)
    pub fn deinit(self: *Object) void {
        c.zend_object_release(self.ptr());
    }

    /// Increment refcount
    pub fn addref(self: *Object) void {
        _ = c.zend_gc_addref(&self.ptr().gc);
    }

    /// Decrement refcount
    pub fn delref(self: *Object) void {
        _ = c.zend_gc_delref(&self.ptr().gc);
    }

    /// Get the class entry
    pub inline fn class(self: *Object) *ClassEntry {
        return ClassEntry.from(self.ptr().ce);
    }

    /// Get object handle
    pub inline fn handle(self: *Object) u32 {
        return self.ptr().handle;
    }

    /// Get object properties
    pub inline fn properties(self: *Object) ?*Array {
        const prop_ptr: ?*c.HashTable = c.zend_std_get_properties(self.ptr());
        return if (prop_ptr) |p| .from(p) else null;
    }

    /// Get property count
    pub fn propertyCount(self: *Object) usize {
        return if (self.properties()) |props| props.len() else 0;
    }

    pub const ConstructorError = error{AccessDenied};

    /// Look up the constructor via PHP's standard handler.
    ///
    /// Returns `null` if the class defines no constructor. Returns
    /// `error.AccessDenied` if the constructor exists but is inaccessible
    /// (private/protected) — in that case a PHP exception is also pending.
    pub fn constructor(self: *Object) ConstructorError!?*Function {
        const fn_ptr = c.zend_std_get_constructor(self.ptr());
        return if (fn_ptr) |fp|
            Function.from(fp)
        else if (errors.hasException()) error.AccessDenied else null;
    }

    /// Resolve a method via PHP's OOP dispatch.
    ///
    /// Goes through the full method resolution chain: handles visibility
    /// (private/protected), triggers `__call` when the method is absent,
    /// and respects inheritance. Use `findMethod` for a direct table lookup.
    pub fn resolveMethod(self: *Object, method_name: []const u8) ?*Function {
        const zstr = String.init(method_name);
        defer zstr.deinit();

        var obj_ptr = self.ptr();
        const fn_ptr = c.zend_std_get_method(@ptrCast(&obj_ptr), zstr.ptr(), null);
        return if (fn_ptr != null) .from(@ptrCast(fn_ptr)) else null;
    }

    /// Look up a method directly from the class function table.
    ///
    /// Unlike `resolveMethod`, this bypasses OOP dispatch (`__call`, visibility checks)
    /// and queries the flattened function table directly. The returned pointer can
    /// be cached and passed to `zend_call_known_instance_method` for repeated calls.
    ///
    /// Note: PHP stores method names lowercase — pass a lowercase `method_name`.
    ///
    /// Returns:
    ///   The function pointer, or null if the method is not in the table
    pub inline fn findMethod(self: *Object, method_name: []const u8) ?*Function {
        return self.class().findMethod(method_name);
    }

    /// Read a property value.
    ///
    /// Returns `error.PhpException` if a magic `__get` handler throws.
    pub fn readProperty(
        self: *Object,
        name: []const u8,
    ) Function.Error!?*c.zval {
        const zstr = String.init(name);
        defer zstr.deinit();

        var rv: c.zval = undefined;
        const result = c.zend_std_read_property(
            self.ptr(),
            zstr.ptr(),
            c.BP_VAR_R,
            null,
            &rv,
        );
        if (errors.hasException()) return error.PhpException;
        return result;
    }

    /// Write a property value.
    ///
    /// Returns `error.PhpException` if a magic `__set` handler throws.
    pub fn writeProperty(
        self: *Object,
        name: []const u8,
        value: *c.zval,
    ) Function.Error!?*c.zval {
        const zstr = String.init(name);
        defer zstr.deinit();

        const result = c.zend_std_write_property(
            self.ptr(),
            zstr.ptr(),
            value,
            null,
        );
        if (errors.hasException()) return error.PhpException;
        return result;
    }

    /// Property existence check mode, passed to `hasProperty`.
    pub const PropertyCheck = enum(c_int) {
        /// `isset($obj->prop)` — property exists and is not null
        isset = c.ZEND_PROPERTY_ISSET,
        /// `!empty($obj->prop)` — property exists and is not empty
        not_empty = c.ZEND_PROPERTY_NOT_EMPTY,
        /// `property_exists($obj, 'prop')` — property exists
        exists = c.ZEND_PROPERTY_EXISTS,
        _,
    };

    /// Check if a property exists.
    ///
    /// Returns `error.PhpException` if a magic `__isset` handler throws.
    pub fn hasProperty(
        self: *Object,
        name: []const u8,
        comptime check: PropertyCheck,
    ) Function.Error!bool {
        const zstr = String.init(name);
        defer zstr.deinit();

        const result = c.zend_std_has_property(self.ptr(), zstr.ptr(), @intFromEnum(check), null);
        if (errors.hasException()) return error.PhpException;
        return result != 0;
    }

    /// Unset a property.
    ///
    /// Returns `error.PhpException` if a magic `__unset` handler throws.
    pub fn unsetProperty(self: *Object, name: []const u8) Function.Error!void {
        const zstr = String.init(name);
        defer zstr.deinit();

        c.zend_std_unset_property(self.ptr(), zstr.ptr(), null);
        if (errors.hasException()) return error.PhpException;
    }

    /// Check if object is an instance of a class
    pub inline fn instanceof(self: *Object, ce: *ClassEntry) bool {
        return c.instanceof_function(self.class().ptr(), ce.ptr());
    }

    pub const CallError = error{MethodNotFound} || Function.Error;

    /// Call a known method by name.
    ///
    /// Resolves the method from the class's function table,
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    ///
    /// Note: PHP stores method names lowercase — pass a lowercase `method_name`.
    ///
    /// Returns:
    ///   error.MethodNotFound if the method is not in the class function table
    ///   error.PhpException if the called method threw a PHP exception
    pub fn call(
        self: *Object,
        method_name: []const u8,
        retval: ?*c.zval,
        params: anytype,
    ) CallError!void {
        const method = self.findMethod(method_name) orelse return error.MethodNotFound;
        try method.callMethod(self, retval, params);
    }

    /// Call a known static method by name.
    ///
    /// Resolves the method from the class's function table,
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    ///
    /// Note: PHP stores method names lowercase — pass a lowercase `method_name`.
    ///
    /// Returns:
    ///   error.MethodNotFound if the method is not in the class function table
    ///   error.PhpException if the called method threw a PHP exception
    pub fn callStatic(
        self: *Object,
        method_name: []const u8,
        ce: *ClassEntry,
        retval: ?*c.zval,
        params: anytype,
    ) CallError!void {
        const method = self.findMethod(method_name) orelse return error.MethodNotFound;
        try method.callStatic(ce, retval, params);
    }

    pub const CallIfExistsError = error{MethodCallFailed} || Function.Error;

    /// Call a method by name, succeeding only if the method exists.
    pub fn callIfExists(
        self: *Object,
        method_name: []const u8,
        retval: ?*c.zval,
        params: []c.zval,
    ) CallIfExistsError!void {
        const zstr = String.init(method_name);
        defer zstr.deinit();

        const result = c.zend_call_method_if_exists(
            self.ptr(),
            zstr.ptr(),
            retval,
            @intCast(params.len),
            if (params.len > 0) @ptrCast(params.ptr) else null,
        );
        if (result == c.FAILURE) return error.MethodCallFailed;
        if (errors.hasException()) return error.PhpException;
    }

    pub const CloneError = error{CloneFailed};

    /// Clone the object.
    ///
    /// Returns `error.CloneFailed` if the object is uncloneable or `__clone` throws.
    /// Check `errors.hasException()` to distinguish.
    pub fn clone(self: *Object) CloneError!*Object {
        const cloned = c.zend_objects_clone_obj(self.ptr());
        if (cloned == null) return error.CloneFailed;
        return @ptrCast(cloned);
    }

    /// Get refcount
    pub inline fn refcount(self: *Object) u32 {
        return c.zend_gc_refcount(&self.ptr().gc);
    }

    /// Check if object is immutable
    pub inline fn isImmutable(self: *Object) bool {
        return (c.GC_FLAGS(self.ptr()) & c.GC_IMMUTABLE) != 0;
    }

    /// Get the case name from an enum case object
    pub fn enumCaseName(self: *Object) []const u8 {
        const zv = c.zend_enum_fetch_case_name(self.ptr());
        return native.asUnchecked(zv, .string);
    }

    /// Get the backing value from a backed enum case, or null if pure enum
    pub fn enumCaseValue(self: *Object) ?*c.zval {
        if (self.enumBackingType() == .undef) return null;
        return c.zend_enum_fetch_case_value(self.ptr());
    }

    /// Get the enum backing type of this object's class
    pub inline fn enumBackingType(self: *Object) ClassEntry.EnumBackingType {
        return self.class().enumBackingType();
    }

    /// Check if this object is an enum case
    pub inline fn isEnum(self: *Object) bool {
        return self.class().isEnum();
    }
};

test {
    @import("std").testing.refAllDecls(Object);
}
