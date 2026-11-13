const std = @import("std");
const assert = std.debug.assert;

const c = @import("../c.zig").c;
const exception = @import("../exception.zig");
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
    /// Uses PHP's native OOM policy: OOM may be delayed or bail out;
    /// exceeding a hard memory limit terminates the process.
    pub fn std() *Object {
        return initStd(.internal("zend_standard_class_def"));
    }

    /// Allocate a standard-layout object and initialize its default properties.
    /// Wraps zend_objects_new() and object_properties_init(); does not dispatch
    /// create_object, check instantiability, or call the PHP constructor.
    /// The caller must ensure class constants are resolved and standard
    /// allocation is valid for this class and its handlers. For arbitrary
    /// classes, use init(), which wraps object_init_ex().
    ///
    /// Ownership: caller owns the returned object; call `release()` when done.
    /// Uses PHP's native OOM policy: OOM may be delayed or bail out;
    /// exceeding a hard memory limit terminates the process.
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
    /// destructor and return PhpException or UnwindExit, preserving the pending exception.
    /// Zend bailouts propagate without running Zig defer/errdefer.
    pub fn init(ce: *ClassEntry) exception.Error!*Object {
        var value = Zval.raw.undef;
        const object_value = Zval.Object.init(&value, ce) catch return exception.pending() orelse error.PhpException;
        const obj = object_value.zendObject();
        if (exception.pending()) |err| {
            c.zend_object_store_ctor_failed(obj.ptr());
            obj.release();
            return exception.pending() orelse err;
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
    /// Classify the pending exception after cleanup, which may trigger exit/die.
    /// Zend bailouts propagate without running Zig defer/errdefer.
    pub fn new(ce: *ClassEntry, params: anytype, named_params: ?*Array) exception.Error!*Object {
        const obj = try init(ce);
        const constructor_fn_or_null = obj.constructor() catch |err| {
            obj.release();
            return exception.pending() orelse err;
        };
        if (constructor_fn_or_null) |constructor_fn| {
            constructor_fn.callMethod(obj, null, params, named_params) catch |err| {
                c.zend_object_store_ctor_failed(obj.ptr());
                obj.release();
                return exception.pending() orelse err;
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
    pub fn tryNew(ce: *ClassEntry, params: anytype, named_params: ?*Array) (exception.Error || bailout.Error)!*Object {
        return bailout.run(struct {
            fn call(class_entry: *ClassEntry, args: @TypeOf(params), named: ?*Array) exception.Error!*Object {
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

    /// Get properties through the object's get_properties handler.
    /// This is not the purpose-specific get_properties_for API.
    ///
    /// Ownership: borrowed table; keep the object alive and do not release the
    /// table. Subsequent object operations may invalidate the table or its slots.
    /// Returns PhpException or UnwindExit if the handler leaves a pending exception.
    pub fn properties(self: *Object) exception.Error!?*Array {
        const prop_ptr = self.ptr().handlers.*.get_properties.?(self.ptr());
        try exception.check();
        return if (prop_ptr) |p| .from(p) else null;
    }

    pub const PropertyPurpose = enum(c.zend_prop_purpose) {
        debug = c.ZEND_PROP_PURPOSE_DEBUG,
        array_cast = c.ZEND_PROP_PURPOSE_ARRAY_CAST,
        serialize = c.ZEND_PROP_PURPOSE_SERIALIZE,
        var_export = c.ZEND_PROP_PURPOSE_VAR_EXPORT,
        json = c.ZEND_PROP_PURPOSE_JSON,
    };

    /// Get a read-only property view for the given purpose; releaseProperties() when done.
    /// Calls object handlers; on exception, releases the view and returns PhpException or
    /// UnwindExit.
    pub fn propertiesFor(self: *Object, purpose: PropertyPurpose) exception.Error!?*Array {
        var value = Zval.raw.init(.object, self); // Borrowed; do not release.
        const result: ?*c.HashTable = c.zend_get_properties_for(&value, @backingInt(purpose));
        if (exception.pending()) |err| {
            c.phpz_release_properties(result);
            return exception.pending() orelse err;
        }
        return if (result) |table| .from(table) else null;
    }

    /// Release a propertiesFor() view, not a borrowed properties() table. Accepts null.
    pub fn releaseProperties(properties_view: ?*Array) void {
        c.phpz_release_properties(if (properties_view) |view| view.ptr() else null);
    }

    /// Get properties through zend_std_get_properties, bypassing a custom
    /// get_properties handler. Lazy initialization may throw a PHP exception.
    ///
    /// Ownership: borrowed table, with the same lifetime as properties().
    pub fn stdProperties(self: *Object) exception.Error!?*Array {
        const prop_ptr: ?*c.HashTable = c.zend_std_get_properties(self.ptr());
        try exception.check();
        return if (prop_ptr) |p| .from(p) else null;
    }

    /// Resolve GC roots through PHP's standard handler, wrapping
    /// `zend_std_get_gc()`.
    ///
    /// Ownership: borrowed properties table owned by the object.
    pub fn gcRoots(self: *Object, table: *?[*]c.zval, n: *c_int) ?*Array {
        const prop_ptr: ?*c.HashTable = c.zend_std_get_gc(self.ptr(), table, n);
        return if (prop_ptr) |p| .from(p) else null;
    }

    pub const ConstructorError = exception.Error;

    /// Look up the constructor through the object's get_constructor handler.
    ///
    /// Ownership: borrowed function pointer owned by the class/runtime.
    ///
    /// Returns null if the handler returns no constructor without an exception.
    /// Returns PhpException or UnwindExit for a pending PHP exception, including visibility
    /// errors and custom handler failures. Zend bailouts propagate directly.
    pub fn constructor(self: *Object) ConstructorError!?*Function {
        const obj = self.ptr();
        const fn_ptr = obj.handlers.*.get_constructor.?(obj);
        try exception.check();
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

    /// Fetch mode for property and dimension reads.
    pub const PropertyReadMode = enum(c_int) {
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

    /// Read through the object's handler in the current PHP scope.
    /// Scratch and result ownership follow readStdProperty().
    pub fn readProperty(self: *Object, name: []const u8, comptime read: PropertyReadMode, scratch: *c.zval) exception.Error!*c.zval {
        const key = String.init(name, false);
        defer key.release();
        return self.readPropertyStr(key, read, scratch);
    }

    /// Like readProperty(), with a borrowed Zend string name.
    pub fn readPropertyStr(self: *Object, name: *String, comptime read: PropertyReadMode, scratch: *c.zval) exception.Error!*c.zval {
        const result = self.ptr().handlers.*.read_property.?(self.ptr(), name.ptr(), @backingInt(read), null, scratch);
        try exception.check();
        return result;
    }

    /// Write through the object's handler in the current PHP scope.
    /// Borrows name and dereferenced value; retains stored values.
    /// The result is borrowed and may alias the input.
    pub fn writeProperty(self: *Object, name: []const u8, value: *c.zval) exception.Error!?*c.zval {
        const key = String.init(name, false);
        defer key.release();
        return self.writePropertyStr(key, value);
    }

    /// Like writeProperty(), with a borrowed Zend string name.
    pub fn writePropertyStr(self: *Object, name: *String, value: *c.zval) exception.Error!?*c.zval {
        assert(!Zval.raw.is(value, .reference));
        const result = self.ptr().handlers.*.write_property.?(self.ptr(), name.ptr(), value, null);
        try exception.check();
        return result;
    }

    /// Read a property value.
    ///
    /// Initialize `scratch` to IS_UNDEF before calling. If `scratch` is no
    /// longer IS_UNDEF after the call, destroy it when done.
    ///
    /// Ownership: returned pointer is either borrowed from the object/runtime or
    /// points at caller-provided scratch. Never dtor the returned pointer
    /// directly; use `Zval.raw.release(scratch)` for scratch cleanup.
    ///
    /// Returns `error.PhpException` or `error.UnwindExit` if a magic `__get` handler throws.
    pub fn readStdProperty(
        self: *Object,
        name: []const u8,
        comptime read: PropertyReadMode,
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
        try exception.check();
        return result;
    }

    /// Write a property value.
    ///
    /// Borrows the dereferenced value; retains stored values.
    /// The result is borrowed and may alias the input.
    ///
    /// Returns `error.PhpException` or `error.UnwindExit` if a magic `__set` handler throws.
    pub fn writeStdProperty(
        self: *Object,
        name: []const u8,
        value: *c.zval,
    ) Function.Error!?*c.zval {
        assert(!Zval.raw.is(value, .reference));
        const zstr = String.init(name, false);
        defer zstr.release();

        const result = c.zend_std_write_property(
            self.ptr(),
            zstr.ptr(),
            value,
            null,
        );
        try exception.check();
        return result;
    }

    /// Property check mode for hasProperty() and hasStdProperty().
    pub const PropertyCheck = enum(c_int) {
        /// `isset($obj->prop)` — property exists and is not null
        isset = c.ZEND_PROPERTY_ISSET,
        /// `!empty($obj->prop)` — property exists and is not empty
        not_empty = c.ZEND_PROPERTY_NOT_EMPTY,
        /// `property_exists($obj, 'prop')` — property exists
        exists = c.ZEND_PROPERTY_EXISTS,
        _,
    };

    /// Check a property through the object's has_property handler.
    ///
    /// Returns PhpException or UnwindExit if the handler leaves a pending exception.
    pub fn hasProperty(
        self: *Object,
        name: []const u8,
        comptime check: PropertyCheck,
    ) exception.Error!bool {
        const zstr = String.init(name, false);
        defer zstr.release();

        const result = self.ptr().handlers.*.has_property.?(self.ptr(), zstr.ptr(), @backingInt(check), null);
        try exception.check();
        return result != 0;
    }

    /// Check a property through zend_std_has_property, bypassing a custom
    /// has_property handler. Standard behavior still includes magic methods.
    /// Returns PhpException or UnwindExit if the operation leaves a pending exception.
    pub fn hasStdProperty(
        self: *Object,
        name: []const u8,
        comptime check: PropertyCheck,
    ) exception.Error!bool {
        const zstr = String.init(name, false);
        defer zstr.release();

        const result = c.zend_std_has_property(self.ptr(), zstr.ptr(), @backingInt(check), null);
        try exception.check();
        return result != 0;
    }

    /// Unset a property.
    ///
    /// Returns `error.PhpException` or `error.UnwindExit` if a magic `__unset` handler throws.
    pub fn unsetStdProperty(self: *Object, name: []const u8) Function.Error!void {
        const zstr = String.init(name, false);
        defer zstr.release();

        c.zend_std_unset_property(self.ptr(), zstr.ptr(), null);
        try exception.check();
    }

    /// Set object property value.
    ///
    /// Refcounted inputs are borrowed; `.mixed` must already be dereferenced.
    /// The property handler retains any value it stores. The caller keeps its
    /// input reference on both success and failure.
    /// `.reference` is not accepted; pass `reference.val()` with `.mixed` instead.
    /// Returns `error.PhpException` or `error.UnwindExit` if the property write raises a PHP
    /// exception.
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
        try exception.check();
    }

    /// Set by a borrowed Zend string name in the object's class scope.
    /// Borrows refcounted inputs; copies .string bytes. Dereference .mixed inputs.
    pub fn setPropertyStr(self: *Object, comptime zk: Zval.Kind, name: *String, value: Zval.Type(zk)) exception.Error!void {
        switch (zk) {
            .mixed => {
                assert(!Zval.raw.is(value, .reference));
                c.zend_update_property_ex(self.class().ptr(), self.ptr(), name.ptr(), value);
            },
            .reference => @compileError("property writes do not accept .reference; pass reference.val() with .mixed instead"),
            .undef, .indirect, .ptr => @compileError("'" ++ @tagName(zk) ++ "' cannot be set as object property"),
            inline else => {
                var temporary = Zval.raw.init(zk, value);
                // Only .string allocates an owned value; other inputs are borrowed.
                defer if (zk == .string) Zval.raw.release(&temporary);
                c.zend_update_property_ex(self.class().ptr(), self.ptr(), name.ptr(), &temporary);
            },
        }
        try exception.check();
    }

    /// Read object property.
    ///
    /// Ownership: returned pointer is either borrowed from the object/runtime
    /// or points at caller-provided scratch. Never dtor the returned pointer
    /// directly; use `Zval.raw.release(scratch)` for scratch cleanup.
    ///
    /// Returns `error.PhpException` or `error.UnwindExit` if a magic `__get` handler throws.
    ///
    /// Initialize `scratch` to IS_UNDEF before calling. If `scratch` is no
    /// longer IS_UNDEF after the call, destroy it when done.
    pub fn property(self: *Object, prop_name: []const u8, silent: bool, scratch: *c.zval) Function.Error!*Zval {
        const ce = self.class().ptr();
        const obj = self.ptr();
        const val = c.zend_read_property(ce, obj, prop_name.ptr, prop_name.len, silent, scratch);
        try exception.check();
        return .from(val);
    }

    /// Like property(), with a borrowed Zend string name and the same class scope
    /// and scratch/result ownership.
    pub fn propertyStr(self: *Object, name: *String, silent: bool, scratch: *c.zval) exception.Error!*Zval {
        const result = c.zend_read_property_ex(self.class().ptr(), self.ptr(), name.ptr(), silent, scratch);
        try exception.check();
        return .from(result);
    }

    /// Read through read_dimension, borrowing offset; null requests append access
    /// if supported. Initialize scratch to IS_UNDEF and release it even on error.
    /// The result is borrowed or points to scratch.
    pub fn readDimension(self: *Object, offset: ?*c.zval, comptime read: PropertyReadMode, scratch: *c.zval) exception.Error!*c.zval {
        const result = self.ptr().handlers.*.read_dimension.?(self.ptr(), offset, @backingInt(read), scratch);
        try exception.check();
        return result;
    }

    /// Write through write_dimension; a null offset appends.
    /// Borrows offset and dereferenced value; retains stored values.
    pub fn writeDimension(self: *Object, offset: ?*c.zval, value: *c.zval) exception.Error!void {
        assert(!Zval.raw.is(value, .reference));
        self.ptr().handlers.*.write_dimension.?(self.ptr(), offset, value);
        try exception.check();
    }

    pub const DimensionCheck = enum(c_int) {
        isset = 0,
        not_empty = 1,
    };

    /// Check a borrowed offset through has_dimension using isset/!empty semantics.
    pub fn hasDimension(self: *Object, offset: *c.zval, check: DimensionCheck) exception.Error!bool {
        const result = self.ptr().handlers.*.has_dimension.?(self.ptr(), offset, @backingInt(check));
        try exception.check();
        return result != 0;
    }

    /// Remove a borrowed offset through unset_dimension.
    pub fn unsetDimension(self: *Object, offset: *c.zval) exception.Error!void {
        self.ptr().handlers.*.unset_dimension.?(self.ptr(), offset);
        try exception.check();
    }

    /// Unset (delete) object property.
    ///
    /// Returns `error.PhpException` or `error.UnwindExit` if a magic `__unset` handler throws.
    pub fn unsetProperty(self: *Object, prop_name: []const u8) Function.Error!void {
        const ce = self.class().ptr();
        const obj = self.ptr();
        c.zend_unset_property(ce, obj, prop_name.ptr, prop_name.len);
        try exception.check();
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
    ///   error.PhpException or error.UnwindExit if the called method threw a PHP exception
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
        try exception.check();
        if (result == c.FAILURE) return error.MethodCallFailed;
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
        try exception.check();
        if (result == c.FAILURE) return error.MethodCallFailed;
    }

    pub const CloneError = error{ Uncloneable, CloneFailed } || exception.Error;

    /// Clone through the object's clone_obj handler.
    ///
    /// Ownership: caller owns the returned object; call `release()` when done.
    ///
    /// Returns Uncloneable when the handler is absent, PhpException or UnwindExit for a
    /// pending PHP exception (releasing any returned clone), or CloneFailed
    /// when the handler returns null without an exception.
    /// Like direct C handler calls, this does not check __clone visibility.
    /// Zend bailouts propagate directly.
    pub fn clone(self: *Object) CloneError!*Object {
        const obj = self.ptr();
        const clone_obj = obj.handlers.*.clone_obj orelse return error.Uncloneable;
        const cloned: ?*c.zend_object = clone_obj(obj);
        if (exception.pending()) |err| {
            if (cloned) |result| c.zend_object_release(result);
            return exception.pending() orelse err;
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
