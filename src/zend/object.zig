const c = @import("../root.zig").c;
const String = @import("string.zig").String;
const Function = @import("function.zig").Function;

pub const Object = opaque {
    pub const Error = error{
        InitFailed,
        CloneFailed,
        MethodCallFailed,
        AccessDenied,
    };

    /// Create a standard object (stdClass)
    pub fn init() Error!*Object {
        const obj = c.zend_objects_new(c.zend_standard_class_def);
        if (obj == null) return Error.InitFailed;
        c.object_properties_init(obj, c.zend_standard_class_def);
        return @ptrCast(obj);
    }

    /// Create an object from a class entry
    pub fn initClass(ce: *c.zend_class_entry) Error!*Object {
        const obj = c.zend_objects_new(ce);
        if (obj == null) return Error.InitFailed;
        c.object_properties_init(obj, ce);
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
    pub inline fn class(self: *Object) *c.zend_class_entry {
        return self.ptr().ce;
    }

    /// Get the class name
    pub fn className(self: *Object) []const u8 {
        const ce = self.class();
        const name = ce.name;
        return name.*.val()[0..name.*.len];
    }

    /// Get object handle
    pub inline fn handle(self: *Object) u32 {
        return self.ptr().handle;
    }

    /// Get object properties as HashTable
    pub inline fn properties(self: *Object) *c.HashTable {
        return c.zend_std_get_properties(self.ptr());
    }

    /// Get property count
    pub fn propertyCount(self: *Object) usize {
        const props = self.properties();
        return @intCast(props.nNumOfElements);
    }

    /// Look up the constructor via PHP's standard handler.
    ///
    /// Returns `null` if the class defines no constructor. Returns
    /// `error.AccessDenied` if the constructor exists but is inaccessible
    /// (private/protected) — in that case a PHP exception is also pending.
    pub fn constructor(self: *Object) Error!?*Function {
        const fn_ptr = c.zend_std_get_constructor(self.ptr());
        return if (fn_ptr) |fp|
            Function.from(fp)
        else if (c.executor_globals.exception != null) Error.AccessDenied else null;
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
    pub fn findMethod(self: *Object, method_name: []const u8) ?*Function {
        const fn_ptr = c.zend_hash_str_find_ptr(
            &self.ptr().ce.*.function_table,
            method_name.ptr,
            method_name.len,
        );
        return if (fn_ptr != null) .from(@ptrCast(@alignCast(fn_ptr))) else null;
    }

    /// Read a property value
    pub fn readProperty(
        self: *Object,
        name: []const u8,
    ) ?*c.zval {
        const zstr = String.init(name);
        defer zstr.deinit();

        return c.zend_std_read_property(
            self.ptr(),
            zstr.ptr(),
            c.BP_VAR_R,
            null,
            null,
        );
    }

    /// Write a property value
    pub fn writeProperty(
        self: *Object,
        name: []const u8,
        value: *c.zval,
    ) ?*c.zval {
        const zstr = String.init(name);
        defer zstr.deinit();

        return c.zend_std_write_property(
            self.ptr(),
            zstr.ptr(),
            value,
            null,
        );
    }

    /// Check if a property exists
    pub fn hasProperty(
        self: *Object,
        name: []const u8,
        has_set_exists: c_int,
    ) bool {
        const zstr = String.init(name);
        defer zstr.deinit();

        return c.zend_std_has_property(self.ptr(), zstr.ptr(), has_set_exists, null) != 0;
    }

    /// Unset a property
    pub fn unsetProperty(self: *Object, name: []const u8) void {
        const zstr = String.init(name);
        defer zstr.deinit();

        c.zend_std_unset_property(self.ptr(), zstr.ptr(), null);
    }

    /// Check if object is an instance of a class
    pub fn instanceof(self: *Object, ce: *c.zend_class_entry) bool {
        return c.instanceof_function(self.class(), ce);
    }

    /// Call a known method by name.
    ///
    /// Resolves the method from the class's function table,
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    ///
    /// Note: PHP stores method names lowercase — pass a lowercase `method_name`.
    ///
    /// Returns:
    ///   Error.MethodCallFailed if the method is not found in the class
    pub fn call(
        self: *Object,
        method_name: []const u8,
        retval: *c.zval,
        params: anytype,
    ) Error!void {
        const method = self.findMethod(method_name) orelse return Error.MethodCallFailed;
        method.callMethod(self.ptr(), retval, params);
    }

    /// Call a known static method by name.
    ///
    /// Resolves the method from the class's function table,
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    ///
    /// Note: PHP stores method names lowercase — pass a lowercase `method_name`.
    ///
    /// Returns:
    ///   Error.MethodCallFailed if the method is not found in the class
    pub fn callStatic(
        self: *Object,
        method_name: []const u8,
        ce: *c.zend_class_entry,
        retval: *c.zval,
        params: anytype,
    ) Error!void {
        const method = self.findMethod(method_name) orelse return Error.MethodCallFailed;
        method.callStatic(ce, retval, params);
    }

    /// Call a method by name, succeeding only if the method exists.
    pub fn callIfExists(
        self: *Object,
        method_name: []const u8,
        retval: *c.zval,
        params: []c.zval,
    ) Error!void {
        const zstr = String.init(method_name);
        defer zstr.deinit();

        const result = c.zend_call_method_if_exists(
            self.ptr(),
            zstr.ptr(),
            retval,
            @intCast(params.len),
            if (params.len > 0) @ptrCast(params.ptr) else null,
        );
        if (result == c.SUCCESS) return;
        return Error.MethodCallFailed;
    }

    /// Clone the object
    pub fn clone(self: *Object) Error!*Object {
        const cloned = c.zend_objects_clone_obj(self.ptr());
        if (cloned == null) return Error.CloneFailed;
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
};

test {
    @import("std").testing.refAllDecls(Object);
}
