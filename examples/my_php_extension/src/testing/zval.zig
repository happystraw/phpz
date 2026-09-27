const std = @import("std");
const phpz = @import("phpz");
const Zval = phpz.Zval;

/// Shared handler for castValue and castReferenceValue.
pub fn castValue(ctx: phpz.Ctx, value: *Zval, type_name: []const u8, convert: bool) !void {
    inline for (.{ .int, .float, .bool, .str, .array, .object }) |kind| {
        if (std.mem.eql(u8, type_name, if (kind == .str) "string" else @tagName(kind))) {
            if (convert) {
                Zval.raw.copy(ctx.retval.ptr(), value.ptr());
                _ = try ctx.retval.convert(kind);
            } else {
                const result = try value.cast(kind);
                ctx.retval.set(kind, result);
            }
            return;
        }
    }
    return error.UnknownCastType;
}
