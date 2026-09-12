const std = @import("std");
const phpz = @import("phpz");

const Resource = struct {
    label: []u8,
    id: u8,

    fn cleanup(self: Resource) void {
        std.debug.print("cleanup {s} {d}\n", .{ self.label, self.id });
        std.heap.c_allocator.free(self.label);
    }
};

fn registerResources(ctx: phpz.GuardCtx, label: []const u8) !void {
    for (1..3) |id| {
        const copy = try std.heap.c_allocator.dupe(u8, label);
        errdefer std.heap.c_allocator.free(copy);
        _ = try ctx.guard(Resource{ .label = copy, .id = @intCast(id) }, Resource.cleanup);
    }
}

pub fn guardResources(ctx: phpz.GuardCtx) !void {
    var callback: phpz.zend.Callable = .nil;
    const args = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
        .{ .callable = .{ .resolve = true } },
        .{ .bool = .{ .optional = true } },
    }, .{ {}, .{ .target = &callback }, {} });
    defer callback.release();

    try registerResources(ctx, args[0]);
    defer std.debug.print("defer {s}\n", .{args[0]});
    try callback.call(null, .{}, null);
    if (args[2] orelse false) return error.GuardFailure;
}

pub fn value(ctx: phpz.GuardCtx) void {
    registerResources(ctx, "closure") catch return;
    ctx.ret.set(.int, 42);
}
