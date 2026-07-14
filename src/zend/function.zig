const errors = @import("../errors.zig");
const phpz = @import("../root.zig");
const c = phpz.c;
const globals = phpz.globals;
const ClassEntry = @import("class_entry.zig").ClassEntry;
const Object = @import("object.zig").Object;
const bailout = @import("bailout.zig");

pub const Function = opaque {
    pub const Error = error{
        PhpException,
    };
    pub const TryCallError = Error || bailout.Error;

    /// Function type classification.
    pub const Kind = enum(@TypeOf(c.ZEND_INTERNAL_FUNCTION)) {
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

    /// Look up a method directly from a class's function table
    pub fn findMethod(ce: *ClassEntry, method_name: []const u8) ?*Function {
        return ce.methods().findPtr(Function, method_name);
    }

    /// Get the function type (internal vs userland).
    pub fn kind(self: *Function) Kind {
        return @enumFromInt(self.ptr().*.type);
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

    /// Call as a global function (no object, no scope).
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    ///
    /// Returns `error.PhpException` if the called function throws a PHP exception.
    pub fn call(self: *Function, retval: ?*c.zval, params: anytype) Error!void {
        try self.invoke(null, null, retval, params);
    }

    /// Call as a global function and convert a Zend bailout into `error.ZendBailout`.
    pub fn tryCall(self: *Function, retval: ?*c.zval, params: anytype) TryCallError!void {
        try self.tryInvoke(null, null, retval, params);
    }

    /// Call as a static method (with class scope, no object).
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    ///
    /// Returns `error.PhpException` if the called method throws a PHP exception.
    pub fn callStatic(self: *Function, ce: *ClassEntry, retval: ?*c.zval, params: anytype) Error!void {
        try self.invoke(null, ce.ptr(), retval, params);
    }

    /// Call as a static method and convert a Zend bailout into `error.ZendBailout`.
    pub fn tryCallStatic(self: *Function, ce: *ClassEntry, retval: ?*c.zval, params: anytype) TryCallError!void {
        try self.tryInvoke(null, ce.ptr(), retval, params);
    }

    /// Call as an instance method on an object.
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    ///
    /// Returns `error.PhpException` if the called method throws a PHP exception.
    pub fn callMethod(self: *Function, obj: *Object, retval: ?*c.zval, params: anytype) Error!void {
        try self.invoke(obj.ptr(), obj.class().ptr(), retval, params);
    }

    /// Call as an instance method and convert a Zend bailout into `error.ZendBailout`.
    pub fn tryCallMethod(self: *Function, obj: *Object, retval: ?*c.zval, params: anytype) TryCallError!void {
        try self.tryInvoke(obj.ptr(), obj.class().ptr(), retval, params);
    }

    inline fn invoke(
        self: *Function,
        obj: ?*c.zend_object,
        scope: ?*c.zend_class_entry,
        retval: ?*c.zval,
        params: anytype,
    ) Error!void {
        const info = @typeInfo(@TypeOf(params));
        if (!(info == .@"struct" and info.@"struct".is_tuple))
            @compileError("params must be a tuple, e.g. .{} or .{a, b}");

        const n = info.@"struct".field_types.len;
        switch (n) {
            0 => c.zend_call_known_function(self.ptr(), obj, scope, retval, 0, null, null),
            else => {
                var arr: [n]c.zval = undefined;
                inline for (0..n) |i| arr[i] = params[i];
                c.zend_call_known_function(self.ptr(), obj, scope, retval, @intCast(n), @ptrCast(&arr), null);
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

                    fn call(frame: *@This()) void {
                        c.zend_call_known_function(frame.function.ptr(), frame.obj, frame.scope, frame.retval, 0, null, null);
                    }
                };
                var frame: CallFrame = .{
                    .function = self,
                    .obj = obj,
                    .scope = scope,
                    .retval = retval,
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

                    fn call(frame: *@This()) void {
                        c.zend_call_known_function(frame.function.ptr(), frame.obj, frame.scope, frame.retval, @intCast(n), @ptrCast(frame.params), null);
                    }
                };
                var frame: CallFrame = .{
                    .function = self,
                    .obj = obj,
                    .scope = scope,
                    .retval = retval,
                    .params = &arr,
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
