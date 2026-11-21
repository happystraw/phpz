const std = @import("std");

const exception = @import("../exception.zig");
const stub = @import("../stub.zig");
const c = @import("../root.zig").c;
const Zval = @import("../zval.zig").Zval;
const Object = @import("object.zig").Object;
const String = @import("string.zig").String;
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
    /// Owned, request-local callable cache. Uses native FCC ownership on PHP 8.3+
    /// and retains the source callable on PHP 8.2.
    pub const Cache = @import("callable_cache.zig").CallableCache;

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
    /// Use addref()/release() to retain it beyond the source lifetime.
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

    /// Retain the resolved callable without rechecking its visibility or scope.
    /// Requires a successfully parsed Callable whose source is still alive.
    /// If parsing released a magic-method trampoline, it must be resolved again
    /// in a scope where the original source is callable. For scope-independent
    /// retention of magic methods, use Cache.init() in the original scope.
    /// The returned cache owns its PHP references and must be deinitialized
    /// and reported to GC.
    pub fn retainCache(self: *Callable) ParseError!Cache {
        return Cache.retain(self);
    }

    /// Get a diagnostic callable name, optionally relative to an object.
    /// Does not validate callability. Ownership: caller owns the returned string;
    /// call release() when done.
    pub fn name(value: *c.zval, object: ?*Object) *String {
        return .from(c.zend_get_callable_name_ex(value, if (object) |obj| obj.ptr() else null));
    }

    /// Check whether a zval contains a callable.
    pub fn isCallable(zv: *c.zval) bool {
        return c.zend_is_callable(zv, 0, null);
    }

    pub const CallError = error{CallFailed} || exception.Error;
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
    /// Returns `error.PhpException` or `error.UnwindExit` if a PHP exception is pending after the
    /// call.
    pub fn call(self: *Callable, retval: ?*c.zval, args: anytype, named_params: ?*Array) CallError!void {
        var fci_copy = self.fci;
        return callWithFci(&fci_copy, &self.fcc, retval, args, named_params);
    }

    /// Invoke using this Callable's own FCI. The caller must have exclusive access
    /// to this Callable throughout the call and any discarded-result cleanup,
    /// including reentry or use from another fiber. Sequential calls may reuse
    /// the Callable. Arguments, ownership, and errors follow `call()`.
    /// Discard or reparse the Callable before reuse if a Zend bailout skips cleanup.
    pub fn callAssumeExclusive(self: *Callable, retval: ?*c.zval, args: anytype, named_params: ?*Array) CallError!void {
        defer resetCallFields(&self.fci);
        return callWithFci(&self.fci, &self.fcc, retval, args, named_params);
    }

    inline fn resetCallFields(fci: *c.zend_fcall_info) void {
        fci.retval = null;
        fci.params = null;
        fci.param_count = 0;
        fci.named_params = null;
    }

    inline fn callWithFci(
        fci: *c.zend_fcall_info,
        fcc: *c.zend_fcall_info_cache,
        retval: ?*c.zval,
        args: anytype,
        named_params: ?*Array,
    ) CallError!void {
        const info = @typeInfo(@TypeOf(args));
        if (!(info == .@"struct" and info.@"struct".is_tuple))
            @compileError("call: args must be a tuple, e.g. .{} or .{a, b}");

        const n = info.@"struct".field_types.len;
        @setEvalBranchQuota(comptime stub.declarationQuota(n));
        var params: [n]c.zval = undefined;
        inline for (0..n) |i| params[i] = args[i];
        fci.param_count = @intCast(n);
        fci.params = if (n == 0) null else @ptrCast(&params);
        fci.named_params = if (named_params) |values| values.ptr() else null;
        const result = if (retval) |out| with_result: {
            fci.retval = out;
            break :with_result c.zend_call_function(fci, fcc);
        } else discarded: {
            var discard = Zval.raw.undef;
            fci.retval = &discard;
            const result = c.zend_call_function(fci, fcc);
            Zval.raw.release(&discard);
            break :discarded result;
        };
        try exception.check();
        if (result == c.FAILURE) return error.CallFailed;
    }

    /// Invoke the callable and convert a Zend bailout into `error.ZendBailout`.
    /// Arguments and ownership follow call(). The boundary includes destruction
    /// of a discarded return value. After bailout, propagate ZendBailout after
    /// native resource cleanup; do not resume normal PHP execution or retry
    /// interrupted return-value cleanup.
    pub fn tryCall(self: *Callable, retval: ?*c.zval, params: anytype, named_params: ?*Array) TryCallError!void {
        var fci = self.fci;
        return tryCallWithFci(&fci, &self.fcc, retval, params, named_params);
    }

    /// Catch Zend bailout during an exclusive call or discarded-result cleanup.
    /// The exclusivity requirement follows `callAssumeExclusive()`. Temporary
    /// FCI fields are cleared even on bailout. Propagate `error.ZendBailout`
    /// after native cleanup.
    pub fn tryCallAssumeExclusive(self: *Callable, retval: ?*c.zval, params: anytype, named_params: ?*Array) TryCallError!void {
        defer resetCallFields(&self.fci);
        return tryCallWithFci(&self.fci, &self.fcc, retval, params, named_params);
    }

    inline fn tryCallWithFci(
        fci: *c.zend_fcall_info,
        fcc: *c.zend_fcall_info_cache,
        retval: ?*c.zval,
        params: anytype,
        named_params: ?*Array,
    ) TryCallError!void {
        return bailout.run(struct {
            fn call(info: *c.zend_fcall_info, cache: *c.zend_fcall_info_cache, result: ?*c.zval, args: @TypeOf(params), named_args: ?*Array) CallError!void {
                return callWithFci(info, cache, result, args, named_args);
            }
        }.call, .{ fci, fcc, retval, params, named_params });
    }

    /// Increment refcounts on `function_name` and `fcc.object`.
    /// Retains a successfully parsed callable; pair each call with release().
    pub inline fn addref(self: *Callable) void {
        Zval.raw.tryAddref(&self.fci.function_name);
        if (self.fcc.object) |obj| Object.addref(.from(obj));
    }

    /// Release references previously acquired by addref(), not borrowed references.
    /// This value must not be used after its referenced callable is destroyed.
    pub inline fn release(self: *Callable) void {
        Zval.raw.release(&self.fci.function_name);
        if (self.fcc.object) |obj| Object.release(.from(obj));
    }
};

test {
    std.testing.refAllDecls(Callable);
}
