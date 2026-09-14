const std = @import("std");
const assert = std.debug.assert;

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
    /// Create a standard object (stdClass).
    ///
    /// Ownership: caller owns the returned object; call `release()` when done.
    /// Allocation failure raises a Zend bailout.
    pub fn std() *Object {
        const std_class = globals.class.rawEntry("zend_standard_class_def");
        return initStd(.from(std_class));
    }

    /// Allocate a standard-layout object and initialize its default properties.
    /// Wraps zend_objects_new() and object_properties_init(); does not dispatch
    /// create_object, check instantiability, or call the PHP constructor.
    /// The caller must ensure class constants are resolved and standard
    /// allocation is valid for this class and its handlers. For arbitrary
    /// classes, use init(), which wraps object_init_ex().
    ///
    /// Ownership: caller owns the returned object; call `release()` when done.
    /// Allocation failure raises a Zend bailout.
    pub fn initStd(ce: *ClassEntry) *Object {
        const obj = c.zend_objects_new(ce.ptr());
        c.object_properties_init(obj, ce.ptr());
        return @ptrCast(obj);
    }

    /// Create an object through object_init_ex without calling its constructor.
    /// Zend checks instantiability, resolves class constants and default property
    /// expressions, and dispatches the class's create_object callback.
    ///
    /// Ownership: caller owns the returned object; call `release()` when done.
    /// Initialization exceptions release the object without calling its PHP
    /// destructor and return PhpException, preserving the pending exception.
    /// Zend bailouts propagate without running Zig defer/errdefer.
    pub fn init(ce: *ClassEntry) errors.Exception!*Object {
        var value = Zval.raw.undef;
        const object_value = Zval.Object.init(&value, ce) catch return error.PhpException;
        const obj = object_value.zendObject();
        if (errors.hasException()) {
            c.zend_object_store_ctor_failed(obj.ptr());
            obj.release();
            return error.PhpException;
        }
        return obj;
    }

    /// Create an object and call its constructor through get_constructor.
    /// Pass positional params as a tuple and null for no named_params.
    /// named_params is borrowed; argument matching and references follow
    /// Function.callMethod(). Without a constructor, all arguments are ignored.
    ///
    /// Ownership: caller owns the returned object; call `release()` when done.
    /// Constructor lookup/call errors release the object. A failed constructor
    /// call also suppresses its PHP destructor. Initialization follows init().
    /// Zend bailouts propagate without running Zig defer/errdefer.
    pub fn new(ce: *ClassEntry, params: anytype, named_params: ?*Array) errors.Exception!*Object {
        const obj = try init(ce);
        errdefer obj.release();
        if (try obj.constructor()) |constructor_fn| {
            constructor_fn.callMethod(obj, null, params, named_params) catch |err| {
                c.zend_object_store_ctor_failed(obj.ptr());
                return err;
            };
        }
        return obj;
    }

    /// Like new(), converting bailouts from initialization, constructor
    /// lookup/call, and ordinary failure cleanup into ZendBailout.
    ///
    /// On bailout, Zig defer/errdefer are skipped; PHP objects remain for request
    /// shutdown. Propagate ZendBailout after native resource cleanup; do not
    /// resume normal PHP execution or retry interrupted object cleanup.
    pub fn tryNew(ce: *ClassEntry, params: anytype, named_params: ?*Array) (errors.Exception || bailout.Error)!*Object {
        return bailout.run(struct {
            fn call(class_entry: *ClassEntry, args: @TypeOf(params), named: ?*Array) errors.Exception!*Object {
                return Object.new(class_entry, args, named);
            }
        }.call, .{ ce, params, named_params });
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

    pub const ConstructorError = errors.Exception;

    /// Look up the constructor through the object's get_constructor handler.
    ///
    /// Ownership: borrowed function pointer owned by the class/runtime.
    ///
    /// Returns null if the handler returns no constructor without an exception.
    /// Returns PhpException for a pending PHP exception, including visibility
    /// errors and custom handler failures. Zend bailouts propagate directly.
    pub fn constructor(self: *Object) ConstructorError!?*Function {
        const obj = self.ptr();
        const fn_ptr = obj.handlers.*.get_constructor.?(obj);
        if (errors.hasException()) return error.PhpException;
        return if (fn_ptr) |fp| Function.from(fp) else null;
    }

    /// Look up a method directly from the class function table.
    ///
    /// Ownership: borrowed function pointer owned by the class entry.
    ///
    /// Queries the flattened function table without visibility checks or `__call`
    /// resolution. The returned pointer can
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
    /// Refcounted inputs are borrowed; `.mixed` must already be dereferenced.
    /// The property handler retains any value it stores. The caller keeps its
    /// input reference on both success and failure.
    /// `.reference` is not accepted; pass `reference.val()` with `.mixed` instead.
    /// Returns `error.PhpException` if the property write raises a PHP exception.
    pub fn setProperty(self: *Object, comptime zk: Zval.Kind, prop_name: []const u8, prop_value: Zval.Type(zk)) Function.Error!void {
        const ce = self.class().ptr();
        const obj = self.ptr();
        switch (zk) {
            .null => c.zend_update_property_null(ce, obj, prop_name.ptr, prop_name.len),
            .bool => c.zend_update_property_bool(ce, obj, prop_name.ptr, prop_name.len, if (prop_value) 1 else 0),
            .int => c.zend_update_property_long(ce, obj, prop_name.ptr, prop_name.len, prop_value),
            .float => c.zend_update_property_double(ce, obj, prop_name.ptr, prop_name.len, prop_value),
            .string => c.zend_update_property_stringl(ce, obj, prop_name.ptr, prop_name.len, prop_value.ptr, prop_value.len),
            .mixed => {
                assert(!Zval.raw.is(prop_value, .reference));
                c.zend_update_property(ce, obj, prop_name.ptr, prop_name.len, prop_value);
            },
            .reference => @compileError("property writes do not accept .reference; pass reference.val() with .mixed instead"),
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
        const result = try bailout.run(Context.call, .{&context});
        if (result == c.FAILURE) return error.MethodCallFailed;
        if (errors.hasException()) return error.PhpException;
    }

    pub const CloneError = error{ Uncloneable, CloneFailed } || errors.Exception;

    /// Clone through the object's clone_obj handler.
    ///
    /// Ownership: caller owns the returned object; call `release()` when done.
    ///
    /// Returns Uncloneable when the handler is absent, PhpException for a
    /// pending PHP exception (releasing any returned clone), or CloneFailed
    /// when the handler returns null without an exception.
    /// Like direct C handler calls, this does not check __clone visibility.
    /// Zend bailouts propagate directly.
    pub fn clone(self: *Object) CloneError!*Object {
        const obj = self.ptr();
        const clone_obj = obj.handlers.*.clone_obj orelse return error.Uncloneable;
        const cloned: ?*c.zend_object = clone_obj(obj);
        if (errors.hasException()) {
            if (cloned) |result| c.zend_object_release(result);
            return error.PhpException;
        }
        return .from(cloned orelse return error.CloneFailed);
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
    std.testing.refAllDecls(Object);
}
