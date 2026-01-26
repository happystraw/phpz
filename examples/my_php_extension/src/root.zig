const std = @import("std");

const phpz = @import("phpz");
const c = phpz.c;

const allocator = @import("allocator.zig");

const classes = @import("classes.zig");

fn startup() !void {
    classes.counter.Class.register();
    classes.human.Class.register();
}

fn shutdown() !void {
    allocator.deinit();
}

// fn active() !void {}
//
// fn deactivate() !void {}

fn info(entry: *phpz.ModuleEntry) void {
    c.php_info_print_table_start();
    c.php_info_print_table_row(2, "MyPHPExtension support", "enabled");
    c.php_info_print_table_row(2, "Version", entry.version);
    c.php_info_print_table_end();
}

comptime {
    phpz.forceTypeResolution();

    _ = @import("functions.zig");

    phpz.module(.{
        .name = "my_php_extension",
        .version = "0.1.0",
        .startup_fn = startup,
        .shutdown_fn = shutdown,
        // .request_startup_fn = active,
        // .request_shutdown_fn = deactivate,
        .info_fn = info,
    });
}
