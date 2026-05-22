fn startup() !void {
    classes.runtime.Class.register();
    classes.context.Class.register();
    classes.exception.Class.register();
    classes.value.Class.register();
}

fn shutdown() !void {
    allocator.deinit();
}

comptime {
    phpz.module(.{
        .name = "pjs",
        .version = "0.1.0",
        .module_startup_fn = startup,
        .module_shutdown_fn = shutdown,
    });
}

const phpz = @import("phpz");

const allocator = @import("allocator.zig");
const classes = @import("classes.zig");
