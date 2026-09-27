const std = @import("std");
const phpz = @import("phpz");

/// Both fixtures pass a borrowed, dereferenced value to the property setters.
pub fn setMixedProperty(ctx: phpz.Ctx, object: *phpz.zend.Object, name: []const u8, input: *phpz.Zval, api: []const u8) !void {
    const value = if (input.is(.reference)) input.asUnchecked(.reference).val() else input.ptr();
    if (std.mem.eql(u8, api, "object")) {
        try object.setProperty(.mixed, name, value);
    } else if (std.mem.eql(u8, api, "static")) {
        try object.class().setStaticProperty(.mixed, name, value);
    } else if (std.mem.eql(u8, api, "zval")) {
        const wrapper = try phpz.Zval.Object.from(&ctx.call.args()[0]);
        try wrapper.set(.mixed, name, value);
    } else {
        return error.UnknownPropertyApi;
    }
}
