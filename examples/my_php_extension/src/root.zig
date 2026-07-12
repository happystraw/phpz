const phpz = @import("phpz");

const allocator = @import("allocator.zig");
const classes = @import("classes.zig");
const functions = @import("functions.zig");
const ini_config = @import("ini.zig");

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
    phpz.module(.{
        .name = "my_php_extension",
        .version = "0.1.0",
        .globals = functions.Globals,
        .classes = &.{
            classes.identifiable.Interface,
            classes.status.Enum,
            classes.role.Enum,
            classes.my_error.Class,
            classes.example_attribute.Class,
            classes.abstract_entity.Class,
            classes.user.Class,
            classes.counter.Class,
            classes.array_like.Class,
            classes.dumper.Class,
        },
        .module_shutdown_fn = shutdown,
        // .request_startup_fn = active,
        // .request_shutdown_fn = deactivate,
        .info_fn = info,
        .ini = &.{
            ini_config.greeting,
            ini_config.max_users,
            ini_config.debug,
            ini_config.mode,
        },
    });
}
