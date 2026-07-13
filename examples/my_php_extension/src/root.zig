const phpz = @import("phpz");
pub const c = phpz.c;

const api = @import("api.zig");
const functions = @import("functions.zig");
const ini = @import("ini.zig");
const metrics = @import("metrics.zig");
const bailout = @import("testing/bailout.zig");

fn info(_: *c.zend_module_entry) void {
    phpz.info.table.start();
    phpz.info.table.header(.{ "my_php_extension support", "enabled" });
    phpz.info.table.row(.{ "Version", "0.1.0" });
    phpz.info.table.end();
}

comptime {
    _ = functions;
    _ = bailout;

    phpz.module(.{
        .name = "my_php_extension",
        .version = "0.1.0",
        .classes = api.classes,
        .ini = ini.definitions,
        .globals = metrics.Globals,
        .observer = metrics.observer,
        .request_startup_fn = metrics.requestStartup,
        .info_fn = info,
    });
}
