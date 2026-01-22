const Object = @This();

inner: *c.zend_object,

pub const Error = error{
    InitFailed,
    InvalidObject,
    CloneFailed,
};

/// Create a standard object (stdClass)
pub fn init() Error!Object {
    const obj = c.zend_objects_new(c.zend_standard_class_def);
    if (obj == null) return Error.InitFailed;
    c.object_properties_init(obj, c.zend_standard_class_def);
    return .{ .inner = obj };
}

/// Create an object from a class entry
pub fn initClass(ce: *c.zend_class_entry) Error!Object {
    const obj = c.zend_objects_new(ce);
    if (obj == null) return Error.InitFailed;
    c.object_properties_init(obj, ce);
    return .{ .inner = obj };
}

/// Create an object from an existing zend_object pointer
pub fn from(obj: *c.zend_object) Object {
    return .{ .inner = obj };
}

/// Release the object (decrement refcount)
pub fn deinit(self: *Object) void {
    c.zend_object_release(self.inner);
}

/// Increment refcount
pub fn addref(self: *Object) void {
    _ = c.GC_ADDREF(@ptrCast(&self.inner.gc));
}

/// Decrement refcount
pub fn delref(self: *Object) u32 {
    return c.GC_DELREF(@ptrCast(&self.inner.gc));
}

/// Get the class entry
pub inline fn class(self: *const Object) *c.zend_class_entry {
    return self.inner.ce;
}

/// Get the class name
pub fn className(self: *const Object) []const u8 {
    const ce = self.class();
    const name = ce.name;
    return @as([*]const u8, @ptrCast(&name.*.val))[0..name.*.len];
}

/// Get object handle
pub inline fn handle(self: *const Object) u32 {
    return self.inner.handle;
}

/// Get object properties as HashTable
pub inline fn properties(self: *Object) *c.HashTable {
    return c.zend_std_get_properties(self.inner);
}

/// Get property count
pub fn propertyCount(self: *Object) usize {
    const props = self.properties();
    return @intCast(props.nNumOfElements);
}

/// Get the constructor function
pub fn constructor(self: *const Object) ?*c.zend_function {
    return c.zend_std_get_constructor(self.inner);
}

/// Get a method by name
pub fn getMethod(self: *Object, method_name: []const u8) ?*c.zend_function {
    const zstr = String.init(method_name);
    defer zstr.deinit();

    var obj_ptr = self.inner;
    return c.zend_std_get_method(&obj_ptr, zstr.inner, null);
}

/// Read a property value
pub fn readProperty(
    self: *Object,
    name: []const u8,
) ?*c.zval {
    const zstr = String.init(name);
    defer zstr.deinit();

    return c.zend_std_read_property(
        self.inner,
        zstr.inner,
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
        self.inner,
        zstr.inner,
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

    return c.zend_std_has_property(self.inner, zstr.inner, has_set_exists, null) != 0;
}

/// Unset a property
pub fn unsetProperty(self: *Object, name: []const u8) void {
    const zstr = String.init(name);
    defer zstr.deinit();

    c.zend_std_unset_property(self.inner, zstr.inner, null);
}

/// Check if object is an instance of a class
pub fn instanceof(self: *const Object, ce: *c.zend_class_entry) bool {
    return c.instanceof_function(self.class(), ce) != 0;
}

/// Call a method on the object (simple version with return value)
pub fn callMethod(
    self: *Object,
    method_name: []const u8,
    retval: *c.zval,
    params: []c.zval,
) Error!void {
    const result = c.zend_call_method(
        self.inner,
        null,
        null,
        method_name.ptr,
        method_name.len,
        retval,
        @intCast(params.len),
        if (params.len > 0) &params[0] else null,
        if (params.len > 1) &params[1] else null,
    );
    if (result == null) return Error.MethodCallFailed;
}

/// Call a known function on the object
pub fn callKnownFunction(
    self: *Object,
    func: *c.zend_function,
    called_scope: ?*c.zend_class_entry,
    retval: *c.zval,
    params: []c.zval,
    named_params: ?*c.HashTable,
) void {
    c.zend_call_known_function(
        func,
        self.inner,
        called_scope,
        retval,
        @intCast(params.len),
        if (params.len > 0) params.ptr else null,
        named_params,
    );
}

/// Call a method if it exists (returns false if method doesn't exist)
pub fn callMethodIfExists(
    self: *Object,
    method_name: []const u8,
    retval: *c.zval,
    params: []c.zval,
) bool {
    const zstr = String.init(method_name);
    defer zstr.deinit();

    const result = c.zend_call_method_if_exists(
        self.inner,
        zstr.inner,
        retval,
        @intCast(params.len),
        if (params.len > 0) params.ptr else null,
    );
    return result == c.SUCCESS;
}

/// Clone the object
pub fn clone(self: *Object) Error!Object {
    const cloned = c.zend_objects_clone_obj(self.inner);
    if (cloned == null) return Error.CloneFailed;
    return .{ .inner = cloned };
}

/// Clone the object with specific scope and properties
pub fn cloneWith(
    self: *Object,
    scope: *const c.zend_class_entry,
    props: *const c.HashTable,
) Error!Object {
    const cloned = c.zend_objects_clone_obj_with(self.inner, scope, props);
    if (cloned == null) return Error.CloneFailed;
    return .{ .inner = cloned };
}

/// Get refcount
pub inline fn refcount(self: *const Object) u32 {
    return c.GC_REFCOUNT(@ptrCast(&self.inner.gc));
}

/// Check if object is immutable
pub inline fn isImmutable(self: *const Object) bool {
    return (c.GC_FLAGS(self.inner) & c.GC_IMMUTABLE) != 0;
}

const c = @import("../root.zig").c;
const String = @import("String.zig");
