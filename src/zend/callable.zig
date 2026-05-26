const std = @import("std");
const c = @import("../root.zig").c;
const native = @import("../zval.zig").Zval.native;

/// Parsed callable ready for invocation.
///
/// Typically obtained via `ctx.call.parse("f", .{&callable.fci, &callable.fcc})`.
///
/// ```zig
/// var cb: Callable = undefined;
/// try ctx.call.parse("f", .{ &cb.fci, &cb.fcc });
/// try cb.call(.{ arg1 });
/// ```
pub const Callable = struct {
    /// Call info: function name, params, retval pointer.
    fci: c.zend_fcall_info,
    /// Cache: resolved function handler, scope, object.
    fcc: c.zend_fcall_info_cache,

    pub const Error = error{
        CallFailed,
    };

    /// Check whether a zval contains a callable.
    pub fn isCallable(zv: *c.zval) bool {
        return c.zend_is_callable(zv, 0, null);
    }

    /// Set the zval to receive the return value, returns self for chaining.
    pub inline fn withRetval(self: *Callable, zv: *c.zval) *Callable {
        self.fci.retval = zv;
        return self;
    }

    /// Invoke the callable with positional arguments (comptime tuple of `c.zval`).
    pub fn call(self: *Callable, args: anytype) Error!void {
        const info = @typeInfo(@TypeOf(args));
        if (!(info == .@"struct" and info.@"struct".is_tuple))
            @compileError("call: args must be a tuple, e.g. .{} or .{a, b}");

        const n = info.@"struct".fields.len;
        switch (n) {
            0 => {
                self.fci.param_count = 0;
                self.fci.params = null;
                self.fci.named_params = null;
                if (c.zend_call_function(&self.fci, &self.fcc) == c.FAILURE) {
                    return Error.CallFailed;
                }
            },
            else => {
                var arr: [n]c.zval = undefined;
                inline for (0..n) |i| arr[i] = args[i];
                self.fci.param_count = @intCast(n);
                self.fci.params = @ptrCast(&arr);
                self.fci.named_params = null;
                if (c.zend_call_function(&self.fci, &self.fcc) == c.FAILURE) {
                    return Error.CallFailed;
                }
            },
        }
    }

    /// Increment refcounts on `function_name` and `fcc.object`.
    /// Prevents premature destruction when the callable is retained.
    pub inline fn addref(self: *Callable) void {
        native.tryAddref(&self.fci.function_name);
        if (self.fcc.object) |obj|
            _ = c.zend_gc_addref(&obj.*.gc);
    }

    /// Decrement refcounts on `function_name` and `fcc.object`.
    /// Frees resources when the last reference is dropped.
    pub inline fn delref(self: *Callable) void {
        native.dtor(&self.fci.function_name);
        if (self.fcc.object) |obj|
            c.zend_object_release(obj);
    }

    /// Release call trampoline from the cache.
    /// Call when the callable will not be invoked (prevents memory leaks).
    pub inline fn release(self: *Callable) void {
        c.zend_release_fcall_info_cache(&self.fcc);
    }

    /// Clear argument memory previously allocated by `zend_fcall_info_args`.
    pub inline fn clearArgs(self: *Callable) void {
        c.zend_fcall_info_args_clear(&self.fci, 0);
    }
};

test {
    std.testing.refAllDecls(Callable);
}
