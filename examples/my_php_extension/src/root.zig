const phpz = @import("phpz");

const api = @import("api.zig");
const functions = @import("functions.zig");
const ini = @import("ini.zig");
const metrics = @import("metrics.zig");
const bailout = @import("testing/bailout.zig");
const superglobals = @import("testing/superglobals.zig");

fn info(m: *phpz.ModuleEntry) void {
    phpz.info.table.start();
    phpz.info.table.header(.{ "my_php_extension support", "enabled" });
    phpz.info.table.row(.{ "version", m.version });
    phpz.info.table.end();
}

comptime {
    const extension = @import("extension_info");

    phpz.namedFunctions(.{
        .hello = functions.hello,
        .greet = functions.greet,
        .@"MyPHPExt\\increment" = functions.increment,
        .@"MyPHPExt\\mapValues" = functions.mapValues,
        .@"MyPHPExt\\Test\\allocatorBailout" = bailout.allocatorBailout,
        .@"MyPHPExt\\Test\\superglobalsSnapshot" = superglobals.superglobalsSnapshot,
        .@"MyPHPExt\\Test\\mutateSuperglobals" = superglobals.mutateSuperglobals,
    });

    phpz.module(.{
        .name = extension.name,
        .version = extension.version,
        .classes = api.classes,
        .ini = ini.definitions,
        .globals = metrics.Globals,
        .observer = metrics.observer,
        .request_startup_fn = metrics.requestStartup,
        .info_fn = info,
    });
}
