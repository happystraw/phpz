pub const Counter = extern struct {
    n: i64,

    pub fn construct(self: *Counter, frame: *phpz.CallFrame) !void {
        var n: i64 = 0;
        try frame.parse("l", .{&n});
        self.n = n;
    }

    pub fn add(self: *Counter, frame: *phpz.CallFrame) !void {
        var n: i64 = 0;
        try frame.parse("l", .{&n});
        self.n +|= n;
    }

    pub fn dec(self: *Counter, frame: *phpz.CallFrame) !void {
        var n: i64 = 0;
        try frame.parse("l", .{&n});
        self.n -|= n;
    }

    pub fn value(self: Counter, ret: *phpz.Zval) void {
        ret.set(.int, self.n);
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
