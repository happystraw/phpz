const c = @import("../root.zig").c;
const String = @import("string.zig").String;

pub const Object = opaque {
    pub const Error = error{
        InitFailed,
        CloneFailed,
        MethodCallFailed,
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
        return @as([*]const u8, @ptrCast(&name.*.val))[0..name.*.len];
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

    /// Get the constructor function
    pub fn constructor(self: *Object) ?*c.zend_function {
        return c.zend_std_get_constructor(self.ptr());
    }

    /// Get a method by name
    pub fn getMethod(self: *Object, method_name: []const u8) ?*c.zend_function {
        const zstr = String.init(method_name);
        defer zstr.deinit();

        var obj_ptr = self.ptr();
        return c.zend_std_get_method(&obj_ptr, zstr.ptr(), null);
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
        return c.instanceof_function(self.class(), ce) != 0;
    }

    /// Call a method if it exists (returns false if method doesn't exist)
    pub fn callMethodIfExists(
        self: *Object,
        method_name: []const u8,
        retval: ?*c.zval,
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

    /// Clone the object with specific scope and properties
    pub fn cloneWith(
        self: *Object,
        scope: *const c.zend_class_entry,
        props: *const c.HashTable,
    ) Error!*Object {
        const cloned = c.zend_objects_clone_obj_with(self.ptr(), scope, props);
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
