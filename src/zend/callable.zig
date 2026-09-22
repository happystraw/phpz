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
///     .{.{ .out = &cb }},
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
    /// Normal parse/call use does not require separate cache cleanup.
    ///
    /// Returns `error.NotCallable` if the zval is not callable
    /// (a PHP error may be pending in `err`).
    /// On success the `fci` and `fcc` fields are populated and ready for `call()`.
    /// The callable is borrowed; its source must remain alive during use.
    /// Use addref()/delref() to retain it beyond the source lifetime.
    /// Release any previous cache and owned references before parsing into this value.
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
        var fci = self.fci;
        fci.retval = retval orelse &discard;

        const n = info.@"struct".field_types.len;
        var params: [n]c.zval = undefined;
        inline for (0..n) |i| params[i] = args[i];
        fci.param_count = @intCast(n);
        fci.params = if (n == 0) null else @ptrCast(&params);
        fci.named_params = if (named_params) |values| values.ptr() else null;
        const result = c.zend_call_function(&fci, &self.fcc);
        if (retval == null) Zval.raw.tryRelease(&discard);
        if (result == c.FAILURE) return error.CallFailed;
        if (errors.hasException()) return error.PhpException;
    }

    /// Invoke the callable and convert a Zend bailout into `error.ZendBailout`.
    /// Arguments and ownership follow call(). The boundary includes destruction
    /// of a discarded return value. After bailout, propagate ZendBailout after
    /// native resource cleanup; do not resume normal PHP execution or retry
    /// interrupted return-value cleanup.
    pub fn tryCall(self: *Callable, retval: ?*c.zval, params: anytype, named_params: ?*Array) TryCallError!void {
        return bailout.run(struct {
            fn call(callable: *Callable, result: ?*c.zval, args: @TypeOf(params), named_args: ?*Array) CallError!void {
                return callable.call(result, args, named_args);
            }
        }.call, .{ self, retval, params, named_params });
    }

    /// Increment refcounts on `function_name` and `fcc.object`.
    /// Retains a successfully parsed callable; pair each call with delref().
    pub inline fn addref(self: *Callable) void {
        Zval.raw.tryAddref(&self.fci.function_name);
        if (self.fcc.object) |obj| Object.addref(.from(obj));
    }

    /// Release references previously acquired by addref(), not borrowed references.
    /// This value must not be used after its referenced callable is destroyed.
    pub inline fn delref(self: *Callable) void {
        Zval.raw.release(&self.fci.function_name);
        if (self.fcc.object) |obj| Object.release(.from(obj));
    }
};

test {
    std.testing.refAllDecls(Callable);
}
