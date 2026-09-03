const phpz = @import("phpz");
const metrics = @import("../metrics.zig");

/// PHP: MyPHPExt\Metrics::snapshot(): array
pub fn snapshot(ctx: phpz.Ctx) !void {
    try metrics.writeSnapshot(ctx);
}

/// PHP: MyPHPExt\Metrics::reset(): void
pub fn reset() void {
    metrics.reset();
}

pub const Class = phpz.Class("MyPHPExt\\Metrics", @This(), .{});
