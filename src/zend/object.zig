const c = @import("../c.zig").c;
const errors = @import("../errors.zig");
const globals = @import("../globals.zig");
const Zval = @import("../zval.zig").Zval;
const Array = @import("array.zig").Array;
const bailout = @import("bailout.zig");
const ClassEntry = @import("class_entry.zig").ClassEntry;
const Function = @import("function.zig").Function;
const String = @import("string.zig").String;

pub const Object = opaque {
    pub const InitError = error{InitFailed};

    /// Create a standard object (stdClass).
    ///
    /// Ownership: caller owns the returned object; call `release()` when done.
    pub fn std() InitError!*Object {
        const std_class = globals.class.rawEntry("zend_standard_class_def");
        const obj = c.zend_objects_new(std_class);
        if (obj == null) return error.InitFailed;
        c.object_properties_init(obj, std_class);
        return @ptrCast(obj);
    }

    /// Create an object from a class entry.
    ///
    /// Ownership: caller owns the returned object; call `release()` when done.
    pub fn init(ce: *ClassEntry) InitError!*Object {
        const obj = c.zend_objects_new(ce.ptr());
        if (obj == null) return error.InitFailed;
        c.object_properties_init(obj, ce.ptr());
        return @ptrCast(obj);
    }

    /// Create an object from an existing zend_object pointer.
    ///
    /// Ownership: borrowed wrapper; no refcount change. Use `addref()` if the
    /// wrapper must outlive the original owner.
    pub inline fn from(obj: *c.zend_object) *Object {
        return @ptrCast(obj);
    }

    /// Get the underlying zend_object pointer.
    ///
    /// Ownership: borrowed raw pointer.
    pub inline fn ptr(self: *Object) *c.zend_object {
        return @ptrCast(@alignCast(self));
    }

    /// Release one owned object reference (decrement refcount, destroy if zero).
    pub inline fn release(self: *Object) void {
        c.zend_object_release(self.ptr());
    }

    /// Increment refcount.
    ///
    /// Ownership: caller owns the added reference and must release/delref it.
    pub fn addref(self: *Object) void {
        _ = c.zend_gc_addref(&self.ptr().gc);
    }

    /// Decrement refcount.
    pub fn delref(self: *Object) void {
        _ = c.zend_gc_delref(&self.ptr().gc);
    }

    /// Get the class entry.
    ///
    /// Ownership: borrowed class entry pointer owned by PHP.
    pub inline fn class(self: *Object) *ClassEntry {
        return ClassEntry.from(self.ptr().ce);
    }

    /// Get object handle
    pub inline fn handle(self: *Object) u32 {
        return self.ptr().handle;
    }

    /// Get object properties.
    ///
    /// Ownership: borrowed properties table owned by the object.
    pub inline fn properties(self: *Object) ?*Array {
        const prop_ptr: ?*c.HashTable = c.zend_std_get_properties(self.ptr());
        return if (prop_ptr) |p| .from(p) else null;
    }

    /// Get property count
    pub fn propertyCount(self: *Object) usize {
        return if (self.properties()) |props| props.len() else 0;
    }

    /// Resolve GC roots through PHP's standard handler, wrapping
    /// `zend_std_get_gc()`.
    ///
    /// Ownership: borrowed properties table owned by the object.
    pub fn gcRoots(self: *Object, table: *?[*]c.zval, n: *c_int) ?*Array {
        const prop_ptr: ?*c.HashTable = c.zend_std_get_gc(self.ptr(), table, n);
        return if (prop_ptr) |p| .from(p) else null;
    }

    pub const ConstructorError = error{AccessDenied};

    /// Look up the constructor via PHP's standard handler.
    ///
    /// Ownership: borrowed function pointer owned by the class entry.
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
    /// Ownership: borrowed function pointer owned by the class entry/runtime.
    ///
    /// Goes through the full method resolution chain: handles visibility
    /// (private/protected), triggers `__call` when the method is absent,
    /// and respects inheritance. Use `findMethod` for a direct table lookup.
    pub fn resolveMethod(self: *Object, method_name: []const u8) ?*Function {
        const zstr = String.init(method_name, false);
        defer zstr.release();

        var obj_ptr = self.ptr();
        const fn_ptr = c.zend_std_get_method(@ptrCast(&obj_ptr), zstr.ptr(), null);
        return if (fn_ptr != null) .from(@ptrCast(fn_ptr)) else null;
    }

    /// Look up a method directly from the class function table.
    ///
    /// Ownership: borrowed function pointer owned by the class entry.
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

    /// Property read fetch mode, passed to `readStdProperty`.
    pub const StdPropertyReadMode = enum(c_int) {
        /// Normal read: `$obj->prop`.
        read = c.BP_VAR_R,
        /// Read for `isset()` / `empty()` style checks.
        isset = c.BP_VAR_IS,
        /// Read in write context.
        write = c.BP_VAR_W,
        /// Read-modify-write context.
        read_write = c.BP_VAR_RW,
        /// Read in unset context.
        unset = c.BP_VAR_UNSET,
        _,
    };

    /// Read a property value.
    ///
    /// Initialize `scratch` to IS_UNDEF before calling. If `scratch` is no
    /// longer IS_UNDEF after the call, destroy it when done.
    ///
    /// Ownership: returned pointer is either borrowed from the object/runtime or
    /// points at caller-provided scratch. Never dtor the returned pointer
    /// directly; use `Zval.raw.tryRelease(scratch)` for scratch cleanup.
    ///
    /// Returns `error.PhpException` if a magic `__get` handler throws.
    pub fn readStdProperty(
        self: *Object,
        name: []const u8,
        comptime read: StdPropertyReadMode,
        scratch: *c.zval,
    ) Function.Error!*c.zval {
        const zstr = String.init(name, false);
        defer zstr.release();

        const result = c.zend_std_read_property(
            self.ptr(),
            zstr.ptr(),
            @backingInt(read),
            null,
            scratch,
        );
        if (errors.hasException()) return error.PhpException;
        return result;
    }

    /// Write a property value.
    ///
    /// Ownership: `value` is consumed according to Zend property write
    /// semantics. If `value` is borrowed and must remain independently owned,
    /// addref/copy it before calling. The returned pointer is borrowed.
    ///
    /// Returns `error.PhpException` if a magic `__set` handler throws.
    pub fn writeStdProperty(
        self: *Object,
        name: []const u8,
        value: *c.zval,
    ) Function.Error!?*c.zval {
        const zstr = String.init(name, false);
        defer zstr.release();

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
        const zstr = String.init(name, false);
        defer zstr.release();

        const result = c.zend_std_has_property(self.ptr(), zstr.ptr(), @backingInt(check), null);
        if (errors.hasException()) return error.PhpException;
        return result != 0;
    }

    /// Unset a property.
    ///
    /// Returns `error.PhpException` if a magic `__unset` handler throws.
    pub fn unsetStdProperty(self: *Object, name: []const u8) Function.Error!void {
        const zstr = String.init(name, false);
        defer zstr.release();

        c.zend_std_unset_property(self.ptr(), zstr.ptr(), null);
        if (errors.hasException()) return error.PhpException;
    }

    /// Set object property value.
    ///
    /// Returns `error.PhpException` if a magic `__set` handler throws.
    pub fn setProperty(self: *Object, comptime zk: Zval.Kind, prop_name: []const u8, prop_value: Zval.Type(zk)) Function.Error!void {
        const ce = self.class().ptr();
        const obj = self.ptr();
        switch (zk) {
            .null => c.zend_update_property_null(ce, obj, prop_name.ptr, prop_name.len),
            .bool => c.zend_update_property_bool(ce, obj, prop_name.ptr, prop_name.len, if (prop_value) 1 else 0),
            .int => c.zend_update_property_long(ce, obj, prop_name.ptr, prop_name.len, prop_value),
            .float => c.zend_update_property_double(ce, obj, prop_name.ptr, prop_name.len, prop_value),
            .string => c.zend_update_property_stringl(ce, obj, prop_name.ptr, prop_name.len, prop_value.ptr, prop_value.len),
            .undef, .indirect, .ptr => @compileError("'" ++ @tagName(zk) ++ "' cannot be set as object property"),
            inline else => {
                var zv: c.zval = undefined;
                Zval.raw.set(&zv, zk, prop_value);
                c.zend_update_property(ce, obj, prop_name.ptr, prop_name.len, &zv);
            },
        }
        if (errors.hasException()) return error.PhpException;
    }

    /// Read object property.
    ///
    /// Ownership: returned pointer is either borrowed from the object/runtime
    /// or points at caller-provided scratch. Never dtor the returned pointer
    /// directly; use `Zval.raw.tryRelease(scratch)` for scratch cleanup.
    ///
    /// Returns `error.PhpException` if a magic `__get` handler throws.
    ///
    /// Initialize `scratch` to IS_UNDEF before calling. If `scratch` is no
    /// longer IS_UNDEF after the call, destroy it when done.
    pub fn property(self: *Object, prop_name: []const u8, silent: bool, scratch: *c.zval) Function.Error!*Zval {
        const ce = self.class().ptr();
        const obj = self.ptr();
        const val = c.zend_read_property(ce, obj, prop_name.ptr, prop_name.len, silent, scratch);
        if (errors.hasException()) return error.PhpException;
        return .from(val);
    }

    /// Unset (delete) object property.
    ///
    /// Returns `error.PhpException` if a magic `__unset` handler throws.
    pub fn unsetProperty(self: *Object, prop_name: []const u8) Function.Error!void {
        const ce = self.class().ptr();
        const obj = self.ptr();
        c.zend_unset_property(ce, obj, prop_name.ptr, prop_name.len);
        if (errors.hasException()) return error.PhpException;
    }

    /// Check if object is an instance of a class or implements an interface.
    pub inline fn instanceof(self: *Object, ce: *ClassEntry) bool {
        return c.instanceof_function(self.class().ptr(), ce.ptr());
    }

    pub const CallError = error{MethodNotFound} || Function.Error;
    pub const TryCallError = error{MethodNotFound} || Function.TryCallError;

    /// Call a known method by name.
    ///
    /// Resolves the method from the class's function table,
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    /// `named_params` is borrowed for the call; semantics follow `Function.call()`.
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
        named_params: ?*Array,
    ) CallError!void {
        const method = self.findMethod(method_name) orelse return error.MethodNotFound;
        try method.callMethod(self, retval, params, named_params);
    }

    /// Call a known method by name and convert a Zend bailout into `error.ZendBailout`.
    /// Arguments and ownership follow `call()`.
    pub fn tryCall(
        self: *Object,
        method_name: []const u8,
        retval: ?*c.zval,
        params: anytype,
        named_params: ?*Array,
    ) TryCallError!void {
        const method = self.findMethod(method_name) orelse return error.MethodNotFound;
        try method.tryCallMethod(self, retval, params, named_params);
    }

    /// Call a known static method by name.
    ///
    /// Resolves the method from the class's function table,
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    /// `named_params` is borrowed for the call; semantics follow `Function.call()`.
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
        named_params: ?*Array,
    ) CallError!void {
        const method = self.findMethod(method_name) orelse return error.MethodNotFound;
        try method.callStatic(ce, retval, params, named_params);
    }

    /// Call a known static method by name and convert a Zend bailout into `error.ZendBailout`.
    /// Arguments and ownership follow `call()`.
    pub fn tryCallStatic(
        self: *Object,
        method_name: []const u8,
        ce: *ClassEntry,
        retval: ?*c.zval,
        params: anytype,
        named_params: ?*Array,
    ) TryCallError!void {
        const method = self.findMethod(method_name) orelse return error.MethodNotFound;
        try method.tryCallStatic(ce, retval, params, named_params);
    }

    pub const CallIfExistsError = error{MethodCallFailed} || Function.Error;
    pub const TryCallIfExistsError = error{MethodCallFailed} || Function.TryCallError;

    /// Call a method by name, succeeding only if the method exists.
    pub fn callIfExists(
        self: *Object,
        method_name: []const u8,
        retval: ?*c.zval,
        params: []c.zval,
    ) CallIfExistsError!void {
        const zstr = String.init(method_name, false);
        defer zstr.release();

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

    /// Call a method by name if it exists and convert a Zend bailout into `error.ZendBailout`.
    pub fn tryCallIfExists(
        self: *Object,
        method_name: []const u8,
        retval: ?*c.zval,
        params: []c.zval,
    ) TryCallIfExistsError!void {
        const zstr = String.init(method_name, false);
        defer zstr.release();

        const CallResult = @typeInfo(@TypeOf(c.zend_call_method_if_exists)).@"fn".return_type.?;
        const Context = struct {
            object: *Object,
            method: *c.zend_string,
            retval: ?*c.zval,
            params: []c.zval,

            fn call(context: *@This()) CallResult {
                return c.zend_call_method_if_exists(
                    context.object.ptr(),
                    context.method,
                    context.retval,
                    @intCast(context.params.len),
                    if (context.params.len > 0) @ptrCast(context.params.ptr) else null,
                );
            }
        };

        var context: Context = .{
            .object = self,
            .method = zstr.ptr(),
            .retval = retval,
            .params = params,
        };
        const result = try bailout.run(Context.call, &context);
        if (result == c.FAILURE) return error.MethodCallFailed;
        if (errors.hasException()) return error.PhpException;
    }

    pub const CloneError = error{CloneFailed};

    /// Clone the object.
    ///
    /// Ownership: caller owns the returned object; call `release()` when done.
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

    /// Get the case name from an enum case object.
    ///
    /// Ownership: borrowed string view owned by the enum case object.
    pub fn enumCaseName(self: *Object) [:0]const u8 {
        const zv = c.zend_enum_fetch_case_name(self.ptr());
        const zstr = zv.*.value.str;
        return zstr.*.val()[0..zstr.*.len :0];
    }

    /// Get the backing value from a backed enum case, or null if pure enum.
    ///
    /// Ownership: borrowed zval pointer owned by the enum case object.
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
