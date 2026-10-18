const std = @import("std");

const c = @import("c.zig").c;
const phpz_options = @import("phpz_options");

const zts = c.USING_ZTS != 0;
const owns_cache = zts and phpz_options.shared;

/// Refresh the shared extension's TSRM cache; no-op for NTS or built-in modules.
pub fn updateCache() void {
    if (comptime owns_cache) c.phpz_tsrm_ls_cache_update();
}

pub fn startup() error{TsrmStartupFailed}!void {
    if (comptime zts) {
        if (!c.php_tsrm_startup()) return error.TsrmStartupFailed;
        updateCache();
    }
}

pub fn shutdown() void {
    if (comptime zts) c.tsrm_shutdown();
    if (comptime owns_cache) c.phpz_tsrm_ls_cache_clear();
}

pub fn initThread() void {
    if (comptime zts) _ = c.ts_resource_ex(0, null);
    updateCache();
}

pub fn freeThread() void {
    if (comptime zts) c.ts_free_thread();
    if (comptime owns_cache) c.phpz_tsrm_ls_cache_clear();
}

pub fn envLock() void {
    if (comptime zts) c.tsrm_env_lock();
}

pub fn envUnlock() void {
    if (comptime zts) c.tsrm_env_unlock();
}

test {
    std.testing.refAllDecls(@This());
}
