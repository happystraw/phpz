const std = @import("std");

const c = @import("c.zig").c;

pub fn startup() error{TsrmStartupFailed}!void {
    if (comptime c.USING_ZTS != 0) {
        if (!c.php_tsrm_startup()) return error.TsrmStartupFailed;
    }
}

pub fn shutdown() void {
    if (comptime c.USING_ZTS != 0) c.tsrm_shutdown();
}

pub fn initThread() void {
    if (comptime c.USING_ZTS != 0) _ = c.ts_resource_ex(0, null);
}

pub fn freeThread() void {
    if (comptime c.USING_ZTS != 0) c.ts_free_thread();
}

pub fn envLock() void {
    c.tsrm_env_lock();
}

pub fn envUnlock() void {
    c.tsrm_env_unlock();
}

test {
    std.testing.refAllDecls(@This());
}
