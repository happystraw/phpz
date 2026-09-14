const std = @import("std");
const phpz = @import("phpz");

/// Both fixtures pass a borrowed, dereferenced value to the property setters.
pub fn setMixedProperty(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .object = .{} },
        .{ .string = .{} },
        .{ .mixed = .{} },
        .{ .string = .{} },
    }, {});
    const input = args[2];
    const value = if (input.is(.reference)) input.asUnchecked(.reference).val() else input.ptr();
    if (std.mem.eql(u8, args[3], "object")) {
        try args[0].setProperty(.mixed, args[1], value);
    } else if (std.mem.eql(u8, args[3], "static")) {
        try args[0].class().setStaticProperty(.mixed, args[1], value);
    } else if (std.mem.eql(u8, args[3], "zval")) {
        const object = try phpz.Zval.Object.from(&ctx.call.args()[0]);
        try object.set(.mixed, args[1], value);
    } else {
        return error.UnknownPropertyApi;
    }
}
