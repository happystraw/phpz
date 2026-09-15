const std = @import("std");
const phpz = @import("phpz");
const Zval = phpz.Zval;

/// Shared handler for castValue and castReferenceValue.
pub fn castValue(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .mixed = .{} },
        .{ .string = .{} },
        .{ .bool = .{} },
    }, {});
    inline for (.{ .int, .float, .bool, .string, .array, .object }) |kind| {
        if (std.mem.eql(u8, args[1], @tagName(kind))) {
            if (args[2]) {
                Zval.raw.copy(ctx.retval.ptr(), args[0].ptr());
                _ = try ctx.retval.convert(kind);
            } else {
                const result = try args[0].cast(kind);
                if (comptime kind == .string) {
                    defer result.release();
                    ctx.retval.set(.string, result.slice());
                } else {
                    ctx.retval.set(kind, result);
                }
            }
            return;
        }
    }
    return error.UnknownCastType;
}
