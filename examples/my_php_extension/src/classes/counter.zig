pub const Counter = extern struct {
    n: i64,

    pub fn construct(self: *Counter, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{ .optional = true } },
        });
        self.n = args[0] orelse 0;
    }

    pub fn add(self: *Counter, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{} },
        });
        self.n +|= args[0];
    }

    pub fn dec(self: *Counter, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{} },
        });
        self.n -|= args[0];
    }

    pub fn value(self: Counter, ctx: phpz.Ctx) void {
        ctx.ret.set(.int, self.n);
    }
};

pub const Class = phpz.Class("MyPHPExt\\Counter", Counter);

comptime {
    Class.method("__construct", .construct);
    Class.method("dec", .dec);
    Class.method("add", .add);
    Class.method("value", .value);
}

const std = @import("std");

const phpz = @import("phpz");
