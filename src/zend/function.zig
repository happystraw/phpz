const c = @import("../root.zig").c;

pub const Function = opaque {
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

    /// Look up a method in a class function table (for static methods)
    pub fn findMethod(ce: *c.zend_class_entry, method_name: []const u8) ?*Function {
        return @ptrCast(@alignCast(c.zend_hash_str_find_ptr(
            &ce.*.function_table,
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
    pub fn call(self: *Function, retval: *c.zval, params: anytype) void {
        const info = @typeInfo(@TypeOf(params));
        if (!(info == .@"struct" and info.@"struct".is_tuple))
            @compileError("call: params must be a tuple, e.g. .{} or .{a, b}");

        const n = info.@"struct".fields.len;
        switch (n) {
            0 => c.zend_call_known_function(self.ptr(), null, null, retval, 0, null, null),
            else => {
                var arr: [n]c.zval = undefined;
                inline for (0..n) |i| arr[i] = params[i];
                c.zend_call_known_function(self.ptr(), null, null, retval, @intCast(n), @ptrCast(&arr), null);
            },
        }
    }

    /// Call as a static method (with class scope, no object).
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    pub fn callStatic(self: *Function, ce: *c.zend_class_entry, retval: *c.zval, params: anytype) void {
        const info = @typeInfo(@TypeOf(params));
        if (!(info == .@"struct" and info.@"struct".is_tuple))
            @compileError("callStatic: params must be a tuple, e.g. .{} or .{a, b}");

        const n = info.@"struct".fields.len;
        switch (n) {
            0 => c.zend_call_known_function(self.ptr(), null, ce, retval, 0, null, null),
            else => {
                var arr: [n]c.zval = undefined;
                inline for (0..n) |i| arr[i] = params[i];
                c.zend_call_known_function(self.ptr(), null, ce, retval, @intCast(n), @ptrCast(&arr), null);
            },
        }
    }

    /// Call as an instance method on an object.
    /// Pass params as a tuple: `.{}`, `.{a}`, `.{a, b}`.
    pub fn callMethod(self: *Function, obj: *c.zend_object, retval: *c.zval, params: anytype) void {
        const info = @typeInfo(@TypeOf(params));
        if (!(info == .@"struct" and info.@"struct".is_tuple))
            @compileError("callMethod: params must be a tuple, e.g. .{} or .{a, b}");

        const n = info.@"struct".fields.len;
        switch (n) {
            0 => c.zend_call_known_function(self.ptr(), obj, obj.ce, retval, 0, null, null),
            else => {
                var arr: [n]c.zval = undefined;
                inline for (0..n) |i| arr[i] = params[i];
                c.zend_call_known_function(self.ptr(), obj, obj.ce, retval, @intCast(n), @ptrCast(&arr), null);
            },
        }
    }
};

test {
    @import("std").testing.refAllDecls(Function);
}
