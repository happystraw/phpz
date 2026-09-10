const std = @import("std");
const errors = @import("../errors.zig");
const phpz = @import("../root.zig");
const c = phpz.c;
const globals = phpz.globals;
const Zval = @import("../zval.zig").Zval;
const bailout = @import("bailout.zig");
const ClassEntry = @import("class_entry.zig").ClassEntry;
const Object = @import("object.zig").Object;
const Array = @import("array.zig").Array;

pub const Function = opaque {
    pub const Error = error{
        PhpException,
    };
    pub const TryCallError = Error || bailout.Error;

    /// Function type classification.
    pub const Kind = enum(@FieldType(c.zend_function, "type")) {
        /// PHP internal function (written in C/Zig)
        internal = c.ZEND_INTERNAL_FUNCTION,
        /// PHP userland function (written in PHP)
        user = c.ZEND_USER_FUNCTION,
        _,
    };

    /// Call context classification.
    pub const Role = enum {
        /// Plain function (not a method)
        function,
        /// Class static method
        static_method,
        /// Instance method
        instance_method,
    };

    /// Wrap a zend_function pointer
    pub inline fn from(fn_ptr: *c.zend_function) *Function {
        return @ptrCast(fn_ptr);
    }

    /// Get the underlying zend_function pointer
    pub inline fn ptr(self: *Function) *c.zend_function {
        return @ptrCast(@alignCast(self));
    }

    /// Look up a function in the global function table
    pub fn find(func_name: []const u8) ?*Function {
        return globals.executor().functions().findPtr(Function, func_name);
    }

    /// Look up a lowercase global function name and initialize its userland runtime cache.
    /// Returns null if not found. Cache allocation may trigger a Zend bailout.
    pub fn fetch(func_name: []const u8) ?*Function {
        const function = c.zend_fetch_function_str(func_name.ptr, func_name.len);
        return if (function != null) .from(function) else null;
    }

    /// Look up a method directly from a class's function table
    pub fn findMethod(ce: *ClassEntry, method_name: []const u8) ?*Function {
        return ce.methods().findPtr(Function, method_name);
    }

    /// Get the function type (internal vs userland).
    pub fn kind(self: *Function) Kind {
        return @fromBackingInt(self.ptr().*.type);
    }

    /// Get the call context (function / static method / instance method).
    pub fn role(self: *Function) Role {
        const zfn = self.ptr();
        if (zfn.*.common.scope == null) return .function;
        if ((zfn.*.common.fn_flags & c.ZEND_ACC_STATIC) != 0) return .static_method;
        return .instance_method;
    }

    /// Get the function name
    pub fn name(self: *Function) [:0]const u8 {
        const zfn = self.ptr();
        const fname = zfn.*.common.function_name;
        if (fname == null) return "";
        return fname.*.val()[0..fname.*.len :0];
    }

    pub const ClosureError = error{ InvalidClosureFunction, InvalidClosureBinding };

    /// Create a native PHP Closure, preserving the function's signature and static variables.
    /// Instance methods require an object; method visibility is not checked.
    /// Argument metadata must outlive the closure. Zend bailouts must terminate the request.
    pub fn toClosure(
        self: *Function,
        result: *Zval,
        options: struct { object: ?*Object = null, called_scope: ?*ClassEntry = null },
    ) ClosureError!void {
        std.debug.assert(result.is(.undef) or result.is(.null));
        const func = self.ptr();
        const flags = func.common.fn_flags;
        if ((self.kind() != .internal and self.kind() != .user) or
            flags & (c.ZEND_ACC_ABSTRACT | c.ZEND_ACC_CLOSURE | c.ZEND_ACC_CALL_VIA_TRAMPOLINE) != 0)
            return error.InvalidClosureFunction;

        const scope = func.common.scope;
        var called_scope = if (options.called_scope) |ce| ce.ptr() else scope;
        switch (self.role()) {
            .function => if (options.object != null or options.called_scope != null) return error.InvalidClosureBinding,
            .static_method => {
                if (options.object != null) return error.InvalidClosureBinding;
                if (!c.instanceof_function(called_scope, scope)) return error.InvalidClosureBinding;
            },
            .instance_method => {
                const object = options.object orelse return error.InvalidClosureBinding;
                if (!object.instanceof(.from(scope.?))) return error.InvalidClosureBinding;
                if (options.called_scope) |ce| {
                    if (ce != object.class()) return error.InvalidClosureBinding;
                }
                called_scope = object.class().ptr();
            },
        }

        var object: ?c.zval = if (options.object) |obj| Zval.raw.init(.object, obj) else null;
        c.zend_create_fake_closure(result.ptr(), func, scope, called_scope, if (object) |*value| value else null);
    }

    /// Call as a global function (no object, no scope).
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    /// `retval` receives the result; pass null to discard it.
    /// The caller owns the result; existing contents of `retval` are not released.
    /// `named_params` is borrowed for the call; pass null for positional arguments only.
    /// String keys name arguments; integer keys append positional arguments and
    /// must precede string keys in iteration order. Matching and references follow Zend.
    ///
    /// Returns `error.PhpException` if the called function throws a PHP exception.
    pub fn call(self: *Function, retval: ?*c.zval, params: anytype, named_params: ?*Array) Error!void {
        try self.invoke(null, null, retval, params, named_params);
    }

    /// Call as a global function and convert a Zend bailout into `error.ZendBailout`.
    /// Arguments and ownership follow `call()`.
    pub fn tryCall(self: *Function, retval: ?*c.zval, params: anytype, named_params: ?*Array) TryCallError!void {
        try self.tryInvoke(null, null, retval, params, named_params);
    }

    /// Call as a static method (with class scope, no object).
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    /// Named arguments and ownership follow `call()`.
    ///
    /// Returns `error.PhpException` if the called method throws a PHP exception.
    pub fn callStatic(self: *Function, ce: *ClassEntry, retval: ?*c.zval, params: anytype, named_params: ?*Array) Error!void {
        try self.invoke(null, ce.ptr(), retval, params, named_params);
    }

    /// Call as a static method and convert a Zend bailout into `error.ZendBailout`.
    /// Arguments and ownership follow `call()`.
    pub fn tryCallStatic(self: *Function, ce: *ClassEntry, retval: ?*c.zval, params: anytype, named_params: ?*Array) TryCallError!void {
        try self.tryInvoke(null, ce.ptr(), retval, params, named_params);
    }

    /// Call as an instance method on an object.
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    /// Named arguments and ownership follow `call()`.
    ///
    /// Returns `error.PhpException` if the called method throws a PHP exception.
    pub fn callMethod(self: *Function, obj: *Object, retval: ?*c.zval, params: anytype, named_params: ?*Array) Error!void {
        try self.invoke(obj.ptr(), obj.class().ptr(), retval, params, named_params);
    }

    /// Call as an instance method and convert a Zend bailout into `error.ZendBailout`.
    /// Arguments and ownership follow `call()`.
    pub fn tryCallMethod(self: *Function, obj: *Object, retval: ?*c.zval, params: anytype, named_params: ?*Array) TryCallError!void {
        try self.tryInvoke(obj.ptr(), obj.class().ptr(), retval, params, named_params);
    }

    inline fn invoke(
        self: *Function,
        obj: ?*c.zend_object,
        scope: ?*c.zend_class_entry,
        retval: ?*c.zval,
        params: anytype,
        named_params: ?*Array,
    ) Error!void {
        const info = @typeInfo(@TypeOf(params));
        if (!(info == .@"struct" and info.@"struct".is_tuple))
            @compileError("params must be a tuple, e.g. .{} or .{a, b}");

        const n = info.@"struct".field_types.len;
        switch (n) {
            0 => c.zend_call_known_function(self.ptr(), obj, scope, retval, 0, null, if (named_params) |args| args.ptr() else null),
            else => {
                var arr: [n]c.zval = undefined;
                inline for (0..n) |i| arr[i] = params[i];
                c.zend_call_known_function(self.ptr(), obj, scope, retval, @intCast(n), @ptrCast(&arr), if (named_params) |args| args.ptr() else null);
            },
        }
        if (errors.hasException()) return error.PhpException;
    }

    inline fn tryInvoke(
        self: *Function,
        obj: ?*c.zend_object,
        scope: ?*c.zend_class_entry,
        retval: ?*c.zval,
        params: anytype,
        named_params: ?*Array,
    ) TryCallError!void {
        const info = @typeInfo(@TypeOf(params));
        if (!(info == .@"struct" and info.@"struct".is_tuple))
            @compileError("params must be a tuple, e.g. .{} or .{a, b}");

        const n = info.@"struct".field_types.len;
        switch (n) {
            0 => {
                const CallFrame = struct {
                    function: *Function,
                    obj: ?*c.zend_object,
                    scope: ?*c.zend_class_entry,
                    retval: ?*c.zval,
                    named_params: ?*Array,

                    fn call(frame: *@This()) void {
                        c.zend_call_known_function(frame.function.ptr(), frame.obj, frame.scope, frame.retval, 0, null, if (frame.named_params) |args| args.ptr() else null);
                    }
                };
                var frame: CallFrame = .{
                    .function = self,
                    .obj = obj,
                    .scope = scope,
                    .retval = retval,
                    .named_params = named_params,
                };
                try bailout.run(void, CallFrame, &frame, CallFrame.call);
            },
            else => {
                var arr: [n]c.zval = undefined;
                inline for (0..n) |i| arr[i] = params[i];
                const CallFrame = struct {
                    function: *Function,
                    obj: ?*c.zend_object,
                    scope: ?*c.zend_class_entry,
                    retval: ?*c.zval,
                    params: *[n]c.zval,
                    named_params: ?*Array,

                    fn call(frame: *@This()) void {
                        c.zend_call_known_function(frame.function.ptr(), frame.obj, frame.scope, frame.retval, @intCast(n), @ptrCast(frame.params), if (frame.named_params) |args| args.ptr() else null);
                    }
                };
                var frame: CallFrame = .{
                    .function = self,
                    .obj = obj,
                    .scope = scope,
                    .retval = retval,
                    .params = &arr,
                    .named_params = named_params,
                };
                try bailout.run(void, CallFrame, &frame, CallFrame.call);
            },
        }
        if (errors.hasException()) return error.PhpException;
    }
};

test {
    @import("std").testing.refAllDecls(Function);
}
