const std = @import("std");

const errors = @import("../errors.zig");
const c = @import("../root.zig").c;
const native = @import("../zval.zig").Zval.native;
const Object = @import("object.zig").Object;

/// Parsed callable ready for invocation.
///
/// Typically obtained via `ctx.call.parseArgs("f", .{&callable.fci, &callable.fcc})`.
///
/// ```zig
/// var cb: Callable = undefined;
/// try ctx.call.parseArgs("f", .{ &cb.fci, &cb.fcc });
/// try cb.call(.{ arg1 });
/// ```
pub const Callable = extern struct {
    /// Call info: function name, params, retval pointer.
    fci: c.zend_fcall_info,
    /// Cache: resolved function handler, scope, object.
    fcc: c.zend_fcall_info_cache,

    pub const nil: Callable = blk: {
        var tmp: Callable = undefined;
        tmp.fci.size = 0;
        tmp.fcc.function_handler = null;
        break :blk tmp;
    };

    pub const ParseError = error{
        NotCallable,
    };

    /// Parse a zval into this Callable (fills fci and fcc).
    ///
    /// Equivalent to PHP's `zend_parse_arg_func()` — resolves a zval containing
    /// a function name, closure, `['class','method']` array, or invocable object
    /// into a `zend_fcall_info`/`zend_fcall_info_cache` pair ready for `call()`.
    ///
    /// Call trampolines are released after parsing for leak safety
    /// (`zend_call_function` re-fetches them automatically).
    ///
    /// When `nullable` is true and the zval is null, the callable is zeroed:
    /// `fci.size` is set to 0 and `fcc.function_handler` to null.
    /// `isCallable()` returns false for such a callable.
    ///
    /// Returns `error.NotCallable` if the zval is not callable
    /// (a PHP error may be pending in `err`).
    /// On success the `fci` and `fcc` fields are populated and ready for `call()`.
    ///
    /// `error_str` optionally receives the error message from `zend_fcall_info_init`
    /// (e.g. "function 'xxx' not found"). Pass `null` to discard it.
    pub fn parse(self: *Callable, zv: *c.zval, comptime nullable: bool, err: ?*?[*:0]u8) ParseError!void {
        if (err) |e| e.* = null;
        if (nullable and native.is(zv, .null)) {
            self.fci.size = 0;
            self.fcc.function_handler = null;
            return;
        }
        if (c.zend_fcall_info_init(zv, 0, &self.fci, &self.fcc, null, @ptrCast(err)) != c.SUCCESS) {
            return error.NotCallable;
        }
        // Release call trampolines: the function may not get called, in which case
        // the trampoline will leak. Force it to be refetched during
        // zend_call_function instead.
        c.zend_release_fcall_info_cache(&self.fcc);
    }

    /// Check whether a zval contains a callable.
    /// When `nullable` is true, a null zval is also accepted.
    pub fn isCallable(zv: *c.zval, comptime nullable: bool) bool {
        if (comptime nullable) if (native.is(zv, .null)) return true;
        return c.zend_is_callable(zv, 0, null);
    }

    /// Set the zval to receive the return value, returns self for chaining.
    pub inline fn withRetval(self: *Callable, zv: *c.zval) *Callable {
        self.fci.retval = zv;
        return self;
    }

    pub const CallError = error{ CallFailed, PhpException };

    /// Invoke the callable with positional arguments (comptime tuple of `c.zval`).
    ///
    /// Returns `error.CallFailed` if the executor is inactive.
    /// Returns `error.PhpException` if the callable throws a PHP exception.
    pub fn call(self: *Callable, args: anytype) CallError!void {
        const info = @typeInfo(@TypeOf(args));
        if (!(info == .@"struct" and info.@"struct".is_tuple))
            @compileError("call: args must be a tuple, e.g. .{} or .{a, b}");

        var discard: c.zval = undefined;
        const owns_retval = self.fci.retval == null;
        if (owns_retval) self.fci.retval = &discard;
        defer if (owns_retval) native.dtor(&discard);

        const n = info.@"struct".fields.len;
        switch (n) {
            0 => {
                self.fci.param_count = 0;
                self.fci.params = null;
                self.fci.named_params = null;
                if (c.zend_call_function(&self.fci, &self.fcc) == c.FAILURE) {
                    return error.CallFailed;
                }
            },
            else => {
                var arr: [n]c.zval = undefined;
                inline for (0..n) |i| arr[i] = args[i];
                self.fci.param_count = @intCast(n);
                self.fci.params = @ptrCast(&arr);
                self.fci.named_params = null;
                if (c.zend_call_function(&self.fci, &self.fcc) == c.FAILURE) {
                    return error.CallFailed;
                }
            },
        }
        if (errors.hasException()) return error.PhpException;
    }

    /// Increment refcounts on `function_name` and `fcc.object`.
    /// Prevents premature destruction when the callable is retained.
    pub inline fn addref(self: *Callable) void {
        native.tryAddref(&self.fci.function_name);
        if (self.fcc.object) |obj| Object.addref(.from(obj));
    }

    /// Decrement refcounts on `function_name` and `fcc.object`.
    pub inline fn delref(self: *Callable) void {
        native.dtor(&self.fci.function_name);
        if (self.fcc.object) |obj| Object.release(.from(obj));
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
