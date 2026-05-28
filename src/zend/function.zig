const errors = @import("../errors.zig");
const c = @import("../root.zig").c;
const ClassEntry = @import("class_entry.zig").ClassEntry;
const Object = @import("object.zig").Object;

pub const Function = opaque {
    pub const Error = error{
        PhpException,
    };

    /// Function type classification.
    pub const Kind = enum(u8) {
        /// PHP internal function (written in C/Zig)
        internal = c.ZEND_INTERNAL_FUNCTION,
        /// PHP userland function (written in PHP)
        user = c.ZEND_USER_FUNCTION,
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
        return @ptrCast(@alignCast(c.zend_hash_str_find_ptr(
            c.executor_globals.function_table,
            func_name.ptr,
            func_name.len,
        )));
    }

    /// Look up a method directly from a class's function table
    pub fn findMethod(ce: *ClassEntry, method_name: []const u8) ?*Function {
        return @ptrCast(@alignCast(c.zend_hash_str_find_ptr(
            &ce.ptr().*.function_table,
            method_name.ptr,
            method_name.len,
        )));
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
    pub fn name(self: *Function) []const u8 {
        const zfn = self.ptr();
        const fname = zfn.*.common.function_name;
        if (fname == null) return "";
        return fname.*.val()[0..fname.*.len];
    }

    /// Call as a global function (no object, no scope).
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    ///
    /// Returns `error.PhpException` if the called function throws a PHP exception.
    pub fn call(self: *Function, retval: ?*c.zval, params: anytype) Error!void {
        try self.invoke(null, null, retval, params);
    }

    /// Call as a static method (with class scope, no object).
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    ///
    /// Returns `error.PhpException` if the called method throws a PHP exception.
    pub fn callStatic(self: *Function, ce: *ClassEntry, retval: ?*c.zval, params: anytype) Error!void {
        try self.invoke(null, ce.ptr(), retval, params);
    }

    /// Call as an instance method on an object.
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    ///
    /// Returns `error.PhpException` if the called method throws a PHP exception.
    pub fn callMethod(self: *Function, obj: *Object, retval: ?*c.zval, params: anytype) Error!void {
        try self.invoke(obj.ptr(), obj.class().ptr(), retval, params);
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

        const n = info.@"struct".fields.len;
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
};

test {
    @import("std").testing.refAllDecls(Function);
}
