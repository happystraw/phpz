const std = @import("std");
const builtin = @import("builtin");

const c = @import("c.zig").c;
const phpz_options = @import("phpz_options");

const zts = c.USING_ZTS != 0;
const owns_cache = zts and phpz_options.shared and phpz_options.static_tsrmls_cache;

/// Refresh the shared extension's TSRM cache; no-op when disabled, NTS, or built-in.
pub fn updateCache() void {
    if (comptime owns_cache) c.phpz_static_tsrmls_cache_update();
}

pub fn startup() error{TsrmStartupFailed}!void {
    if (comptime zts) {
        if (!c.php_tsrm_startup()) return error.TsrmStartupFailed;
        updateCache();
        initTcbOffset();
    }
}

pub fn shutdown() void {
    if (comptime zts) c.tsrm_shutdown();
    if (comptime owns_cache) c.phpz_static_tsrmls_cache_clear();
}

pub fn initThread() void {
    if (comptime zts) _ = c.ts_resource_ex(0, null);
    updateCache();
}

pub fn freeThread() void {
    if (comptime zts) c.ts_free_thread();
    if (comptime owns_cache) c.phpz_static_tsrmls_cache_clear();
}

pub fn envLock() void {
    if (comptime zts) c.tsrm_env_lock();
}

pub fn envUnlock() void {
    if (comptime zts) c.tsrm_env_unlock();
}

/// On Linux, PHP exports the thread-pointer offset of its own TSRM cache for the
/// JIT. The cache is valid while the calling thread owns live TSRM resources;
/// it must not be read after freeThread() or shutdown(). Zero means unavailable.
const tcb_fast_path_enabled = zts and phpz_options.tsrmls_cache_tcb_fast_path and
    builtin.os.tag == .linux and (builtin.cpu.arch == .x86_64 or builtin.cpu.arch == .aarch64);
var tsrmls_cache_tcb_offset: usize = 0;

/// Look up PHP's TLS layout. Called at module startup, before other threads run PHP.
pub fn initTcbOffset() void {
    if (comptime tcb_fast_path_enabled) @atomicStore(usize, &tsrmls_cache_tcb_offset, c.tsrm_get_ls_cache_tcb_offset(), .monotonic);
}

inline fn readCacheFromTcb(offset: usize) ?*anyopaque {
    // Same thread pointer reads as std.os.linux.tls, which is off limits with libc.
    const thread_pointer = switch (comptime builtin.cpu.arch) {
        .x86_64 => asm ("movq %%fs:0, %[tp]"
            : [tp] "=r" (-> usize),
        ),
        .aarch64 => asm ("mrs %[tp], tpidr_el0"
            : [tp] "=r" (-> usize),
        ),
        else => unreachable,
    };
    return @as(*const ?*anyopaque, @ptrFromInt(thread_pointer +% offset)).*;
}

/// The calling thread's TSRM storage. ZTS only.
pub inline fn localStorage() *anyopaque {
    if (comptime !zts) unreachable else {
        if (comptime tcb_fast_path_enabled) {
            const offset = @atomicLoad(usize, &tsrmls_cache_tcb_offset, .monotonic);
            if (offset != 0) if (readCacheFromTcb(offset)) |ls| return ls;
        }
        if (comptime phpz_options.static_tsrmls_cache) {
            return c.phpz_static_tsrmls_cache_get() orelse refreshCache();
        }
        return c.tsrm_get_ls_cache().?;
    }
}

/// Fill the cache for a thread that reached phpz before any refresh hook ran.
noinline fn refreshCache() *anyopaque {
    updateCache();
    if (comptime zts and phpz_options.static_tsrmls_cache) {
        return c.phpz_static_tsrmls_cache_get() orelse c.tsrm_get_ls_cache().?;
    }
    return c.tsrm_get_ls_cache().?;
}

/// Storage at a fast TSRM offset, like TSRMG_FAST_BULK. ZTS only.
pub inline fn fastBulk(comptime T: type, offset: usize) *T {
    return @ptrFromInt(@intFromPtr(localStorage()) +% offset);
}

/// Storage of a TSRM resource id, like TSRMG_BULK. ZTS only.
pub inline fn bulk(comptime T: type, id: c.phpz_rsrc_id) *T {
    const table: *const [*]?*anyopaque = @ptrCast(@alignCast(localStorage()));
    return @ptrCast(@alignCast(table.*[@intCast(id - 1)].?));
}

test {
    std.testing.refAllDecls(@This());
}
