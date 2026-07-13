const phpz = @import("phpz");
const metrics = @import("../metrics.zig");

const methods = struct {
    /// PHP: MyPHPExt\Metrics::__construct()
    fn construct() void {}

    /// PHP: MyPHPExt\Metrics::snapshot(): array
    fn snapshot(ctx: phpz.Ctx) !void {
        try metrics.writeSnapshot(ctx);
    }

    /// PHP: MyPHPExt\Metrics::reset(): void
    fn reset() void {
        metrics.reset();
    }
};

pub const Class = phpz.SimpleClass("MyPHPExt\\Metrics", methods);

comptime {
    Class.method("__construct", methods.construct);
    Class.method("snapshot", methods.snapshot);
    Class.method("reset", methods.reset);
}
