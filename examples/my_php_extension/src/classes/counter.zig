pub const Counter = extern struct {
    n: i64,

    pub fn construct(self: *Counter, ctx: *phpz.ExecContext) !void {
        var n: i64 = 0;
        try ctx.parse("l", .{&n});
        self.n = n;
    }

    pub fn add(self: *Counter, ctx: *phpz.ExecContext) !void {
        var n: i64 = 0;
        try ctx.parse("l", .{&n});
        self.n +|= n;
    }

    pub fn dec(self: *Counter, ctx: *phpz.ExecContext) !void {
        var n: i64 = 0;
        try ctx.parse("l", .{&n});
        self.n -|= n;
    }

    pub fn value(self: Counter) i64 {
        return self.n;
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
