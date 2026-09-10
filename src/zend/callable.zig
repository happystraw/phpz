const std = @import("std");

const errors = @import("../errors.zig");
const c = @import("../root.zig").c;
const Zval = @import("../zval.zig").Zval;
const Object = @import("object.zig").Object;
const Array = @import("array.zig").Array;
const bailout = @import("bailout.zig");

/// Parsed callable ready for invocation.
///
/// Typically resolved through `ctx.call.expectArgs`.
///
/// ```zig
/// var cb: Callable = .nil;
/// _ = try ctx.call.expectArgs(
///     &.{.{ .callable = .{ .resolve = true } }},
///     .{.{ .target = &cb }},
/// );
/// try cb.call(null, .{ arg1 }, null);
/// ```
pub const Callable = struct {
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
    /// Resolves a zval containing
    /// a function name, closure, `['class','method']` array, or invocable object
    /// into a `zend_fcall_info`/`zend_fcall_info_cache` pair ready for `call()`.
    ///
    /// Call trampolines are released after parsing for leak safety
    /// (`zend_call_function` re-fetches them automatically).
    ///
    /// Returns `error.NotCallable` if the zval is not callable
    /// (a PHP error may be pending in `err`).
    /// On success the `fci` and `fcc` fields are populated and ready for `call()`.
    ///
    /// `err` optionally receives the error message from `zend_fcall_info_init`
    /// (e.g. "function 'xxx' not found"). Pass `null` to discard it.
    pub fn parse(self: *Callable, zv: *c.zval, err: ?*?[*:0]u8) ParseError!void {
        if (err) |e| e.* = null;
        if (c.zend_fcall_info_init(zv, 0, &self.fci, &self.fcc, null, @ptrCast(err)) != c.SUCCESS) {
            return error.NotCallable;
        }
        // Release call trampolines: the function may not get called, in which case
        // the trampoline will leak. Force it to be refetched during
        // zend_call_function instead.
        c.zend_release_fcall_info_cache(&self.fcc);
    }

    /// Check whether a zval contains a callable.
    pub fn isCallable(zv: *c.zval) bool {
        return c.zend_is_callable(zv, 0, null);
    }

    pub const CallError = error{ CallFailed, PhpException };
    pub const TryCallError = CallError || bailout.Error;

    /// Invoke the callable with positional and optional named arguments.
    /// Pass args as a tuple of `c.zval`: `.{}`, `.{a}`, `.{a, b}`.
    /// `retval` receives the result; pass null to discard it.
    /// The caller owns the result; existing contents of `retval` are not released.
    /// `named_params` is borrowed for the call; pass null for positional arguments only.
    /// String keys name arguments; integer keys append positional arguments and
    /// must precede string keys in iteration order. Matching and references follow Zend.
    ///
    /// Returns `error.CallFailed` if the executor is inactive.
    /// Returns `error.PhpException` if a PHP exception is pending after the call.
    pub fn call(self: *Callable, retval: ?*c.zval, args: anytype, named_params: ?*Array) CallError!void {
        const info = @typeInfo(@TypeOf(args));
        if (!(info == .@"struct" and info.@"struct".is_tuple))
            @compileError("call: args must be a tuple, e.g. .{} or .{a, b}");

        var discard: c.zval = Zval.raw.undef;
        self.fci.retval = retval orelse &discard;

        const n = info.@"struct".field_types.len;
        const result = switch (n) {
            0 => blk: {
                self.fci.param_count = 0;
                self.fci.params = null;
                self.fci.named_params = if (named_params) |values| values.ptr() else null;
                break :blk c.zend_call_function(&self.fci, &self.fcc);
            },
            else => blk: {
                var arr: [n]c.zval = undefined;
                inline for (0..n) |i| arr[i] = args[i];
                self.fci.param_count = @intCast(n);
                self.fci.params = @ptrCast(&arr);
                self.fci.named_params = if (named_params) |values| values.ptr() else null;
                break :blk c.zend_call_function(&self.fci, &self.fcc);
            },
        };
        if (retval == null) Zval.raw.tryRelease(&discard);
        if (result == c.FAILURE) return error.CallFailed;
        if (errors.hasException()) return error.PhpException;
    }

    /// Invoke the callable and convert a Zend bailout into `error.ZendBailout`.
    /// Arguments and ownership follow `call()`.
    pub fn tryCall(self: *Callable, retval: ?*c.zval, args: anytype, named_params: ?*Array) TryCallError!void {
        const info = @typeInfo(@TypeOf(args));
        if (!(info == .@"struct" and info.@"struct".is_tuple))
            @compileError("tryCall: args must be a tuple, e.g. .{} or .{a, b}");

        var discard: c.zval = Zval.raw.undef;
        self.fci.retval = retval orelse &discard;

        const n = info.@"struct".field_types.len;
        const CallResult = @typeInfo(@TypeOf(c.zend_call_function)).@"fn".return_type.?;
        const CallFrame = struct {
            callable: *Callable,
            discard: ?*c.zval,

            fn call(frame: *@This()) CallResult {
                defer if (frame.discard) |value| Zval.raw.tryRelease(value);
                return c.zend_call_function(&frame.callable.fci, &frame.callable.fcc);
            }
        };

        var frame: CallFrame = .{
            .callable = self,
            .discard = if (retval == null) &discard else null,
        };
        const result = switch (n) {
            0 => blk: {
                self.fci.param_count = 0;
                self.fci.params = null;
                self.fci.named_params = if (named_params) |values| values.ptr() else null;
                break :blk try bailout.run(CallResult, CallFrame, &frame, CallFrame.call);
            },
            else => blk: {
                var arr: [n]c.zval = undefined;
                inline for (0..n) |i| arr[i] = args[i];
                self.fci.param_count = @intCast(n);
                self.fci.params = @ptrCast(&arr);
                self.fci.named_params = if (named_params) |values| values.ptr() else null;
                break :blk try bailout.run(CallResult, CallFrame, &frame, CallFrame.call);
            },
        };

        if (result == c.FAILURE) return error.CallFailed;
        if (errors.hasException()) return error.PhpException;
    }

    /// Increment refcounts on `function_name` and `fcc.object`.
    /// Prevents premature destruction when the callable is retained.
    pub inline fn addref(self: *Callable) void {
        Zval.raw.tryAddref(&self.fci.function_name);
        if (self.fcc.object) |obj| Object.addref(.from(obj));
    }

    /// Decrement refcounts on `function_name` and `fcc.object`.
    pub inline fn delref(self: *Callable) void {
        Zval.raw.release(&self.fci.function_name);
        if (self.fcc.object) |obj| Object.release(.from(obj));
    }

    /// Release call trampoline from the cache.
    /// Call when the callable will not be invoked (prevents memory leaks).
    pub inline fn release(self: *Callable) void {
        c.zend_release_fcall_info_cache(&self.fcc);
    }
};

test {
    std.testing.refAllDecls(Callable);
}
