const phpz = @import("phpz");

pub const Counter = extern struct {
    n: i64,

    pub fn construct(self: *Counter, ctx: phpz.Ctx) !void {
        var n: i64 = 0;
        try ctx.call.parse("|l", .{&n});
        self.n = n;
    }

    pub fn add(self: *Counter, ctx: phpz.Ctx) !void {
        var n: i64 = 0;
        try ctx.call.parse("l", .{&n});
        self.n +|= n;
    }

    pub fn dec(self: *Counter, ctx: phpz.Ctx) !void {
        var n: i64 = 0;
        try ctx.call.parse("l", .{&n});
        self.n -|= n;
    }

    pub fn value(self: Counter, ctx: phpz.Ctx) void {
        ctx.ret.set(.int, self.n);
    }
};

pub const Class = phpz.Class("Counter", Counter);

comptime {
    Class.method("__construct", .construct);
    Class.method("add", .add);
    Class.method("dec", .dec);
    Class.method("value", .value);
}
