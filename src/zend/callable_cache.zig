const std = @import("std");
const c = @import("../root.zig").c;
const globals = @import("../globals.zig");
const exception = @import("../exception.zig");
const bailout = @import("bailout.zig");
const stub = @import("../stub.zig");
const Zval = @import("../zval.zig").Zval;
const Array = @import("array.zig").Array;
const Callable = @import("callable.zig").Callable;
const GcBuffer = @import("../gc.zig").GcBuffer;

/// An owned cache for calls beyond the source zval's lifetime. Uses native FCC
/// ownership on PHP 8.3+ and retains the source callable on PHP 8.2.
/// Request-local, not persistent across requests. Do not copy after initialization;
/// move ownership and deinit() once. Report it to GC when stored in a PHP object.
/// PHP 8.2 refetches magic-method trampolines on each invocation, requiring the
/// source to remain callable in the invocation scope; PHP 8.3+ retains trampolines.
pub const CallableCache = if (c.PHP_VERSION_ID >= 80300) NativeCache else LegacyCache;

const NativeCache = struct {
    fcc: c.zend_fcall_info_cache,

    pub const nil: NativeCache = .{ .fcc = std.mem.zeroes(c.zend_fcall_info_cache) };

    /// Resolve and retain the handler, bound object, closure and any trampoline.
    /// The source is borrowed only during initialization. An optional error
    /// message follows Callable.parse() ownership rules.
    pub fn init(value: *c.zval, err: ?*?[*:0]u8) Callable.ParseError!NativeCache {
        if (err) |message| message.* = null;
        var self: NativeCache = .nil;
        var fci: c.zend_fcall_info = undefined;
        if (c.zend_fcall_info_init(value, 0, &fci, &self.fcc, null, @ptrCast(err)) != c.SUCCESS) {
            return error.NotCallable;
        }
        c.zend_fcc_addref(&self.fcc);
        return self;
    }

    /// Retain an already resolved ordinary handler without resolving its name
    /// in the current scope. Released/live trampolines require fresh resolution;
    /// never shallow-copy ownership of a heap-allocated trampoline.
    pub fn retain(source: *Callable) Callable.ParseError!NativeCache {
        std.debug.assert(source.fci.size != 0);
        if (source.fcc.function_handler) |handler| {
            if (handler.*.common.fn_flags & c.ZEND_ACC_CALL_VIA_TRAMPOLINE == 0) {
                var self: NativeCache = .{ .fcc = source.fcc };
                c.zend_fcc_addref(&self.fcc);
                return self;
            }
        }
        return init(&source.fci.function_name, null);
    }

    pub fn isInitialized(self: *const NativeCache) bool {
        return self.fcc.function_handler != null;
    }

    /// Release ownership, including a retained trampoline. Safe on nil and after
    /// deinit(); invalidate first so PHP destructors cannot reenter this cache.
    pub fn deinit(self: *NativeCache) void {
        if (!self.isInitialized()) return;
        var fcc = self.fcc;
        self.* = .nil;
        c.zend_fcc_dtor(&fcc);
    }

    /// Report the owned object/closure edges for cycle collection.
    pub fn addToGc(self: *NativeCache, buffer: *GcBuffer) void {
        if (self.isInitialized()) c.zend_get_gc_buffer_add_fcc(buffer.ptr(), &self.fcc);
    }

    /// Invoke the retained FCC; requires an initialized cache.
    /// Argument and return ownership follow Callable.call().
    /// Trampolines are copied by Zend for each call, so magic methods are reusable.
    pub fn call(self: *NativeCache, retval: ?*c.zval, args: anytype, named_params: ?*Array) Callable.CallError!void {
        const info = @typeInfo(@TypeOf(args));
        if (!(info == .@"struct" and info.@"struct".is_tuple))
            @compileError("call: args must be a tuple, e.g. .{} or .{a, b}");
        std.debug.assert(self.isInitialized());
        if (!globals.executor().ptr().active) return error.CallFailed;
        const n = info.@"struct".field_types.len;
        @setEvalBranchQuota(comptime stub.declarationQuota(n));
        var params: [n]c.zval = undefined;
        inline for (0..n) |i| params[i] = args[i];
        var discard = Zval.raw.undef;
        c.zend_call_known_fcc(
            &self.fcc,
            retval orelse &discard,
            @intCast(n),
            if (n == 0) null else @ptrCast(&params),
            if (named_params) |values| values.ptr() else null,
        );
        if (retval == null) Zval.raw.release(&discard);
        try exception.check();
    }

    /// Catch Zend bailouts across invocation and discarded-result cleanup.
    /// After native cleanup, propagate ZendBailout without resuming PHP execution.
    pub fn tryCall(self: *NativeCache, retval: ?*c.zval, params: anytype, named_params: ?*Array) Callable.TryCallError!void {
        return bailout.run(struct {
            fn call(cache: *NativeCache, result: ?*c.zval, args: @TypeOf(params), named: ?*Array) Callable.CallError!void {
                return cache.call(result, args, named);
            }
        }.call, .{ self, retval, params, named_params });
    }
};

const LegacyCache = struct {
    callable: Callable,

    pub const nil: LegacyCache = .{ .callable = .nil };

    /// PHP 8.2 keeps the original callable zval alive and refetches magic-method
    /// trampolines through zend_call_function(), rather than owning an FCC alone.
    pub fn init(value: *c.zval, err: ?*?[*:0]u8) Callable.ParseError!LegacyCache {
        var self: LegacyCache = .nil;
        try self.callable.parse(value, err);
        self.callable.addref();
        return self;
    }

    /// Preserve an existing resolved handler and its original scope. PHP 8.2
    /// still refetches released magic trampolines when invoking the callable.
    pub fn retain(source: *Callable) Callable.ParseError!LegacyCache {
        std.debug.assert(source.fci.size != 0);
        if (source.fcc.function_handler) |handler| {
            if (handler.*.common.fn_flags & c.ZEND_ACC_CALL_VIA_TRAMPOLINE != 0)
                return init(&source.fci.function_name, null);
        }
        var self: LegacyCache = .{ .callable = source.* };
        self.callable.addref();
        return self;
    }

    pub fn isInitialized(self: *const LegacyCache) bool {
        return self.callable.fci.size != 0;
    }

    pub fn deinit(self: *LegacyCache) void {
        if (!self.isInitialized()) return;
        var callable = self.callable;
        self.* = .nil;
        callable.release();
    }

    pub fn addToGc(self: *LegacyCache, buffer: *GcBuffer) void {
        buffer.addCallable(&self.callable);
    }

    /// Requires an initialized cache; argument and return ownership follow Callable.call().
    pub fn call(self: *LegacyCache, retval: ?*c.zval, args: anytype, named_params: ?*Array) Callable.CallError!void {
        std.debug.assert(self.isInitialized());
        return self.callable.call(retval, args, named_params);
    }

    /// Requires an initialized cache, as for call().
    pub fn tryCall(self: *LegacyCache, retval: ?*c.zval, params: anytype, named_params: ?*Array) Callable.TryCallError!void {
        std.debug.assert(self.isInitialized());
        return self.callable.tryCall(retval, params, named_params);
    }
};

test {
    std.testing.refAllDecls(CallableCache);
}
