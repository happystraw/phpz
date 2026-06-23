const phpz = @import("phpz");

const allocator = @import("allocator.zig");
const classes = @import("classes.zig");
const ini_config = @import("ini.zig");

fn startup() !void {
    classes.identifiable.Interface.register();
    classes.status.Enum.register();
    classes.role.Enum.register();
    classes.my_error.Class.register();
    classes.example_attribute.Class.register();
    classes.abstract_entity.Class.register();
    classes.user.Class.register();
    classes.counter.Class.register();
    classes.array_like.Class.register();
    classes.dumper.Class.register();
}

fn shutdown() !void {
    allocator.deinit();
}

// fn active() !void {}
//
// fn deactivate() !void {}

fn info(entry: *phpz.ModuleEntry) void {
    phpz.info.table.start();
    phpz.info.table.row(.{ "MyPHPExtension support", "enabled" });
    phpz.info.table.row(.{ "Version", entry.version });
    phpz.info.table.end();
}

comptime {
    _ = @import("functions.zig");

    phpz.module(.{
        .name = "my_php_extension",
        .version = "0.1.0",
        .module_startup_fn = startup,
        .module_shutdown_fn = shutdown,
        // .request_startup_fn = active,
        // .request_shutdown_fn = deactivate,
        .info_fn = info,
        .ini_defs = &ini_config.defs,
    });
}
