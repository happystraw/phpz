const Human = extern struct {
    name: [*]u8,
    name_len: usize,
    age: u8 = 0,

    pub fn register(impl: anytype) *phpz.ClassEntry {
        return impl(c.zend_ce_stringable);
    }

    pub fn construct(self: *Human, ctx: *phpz.ExecContext) !void {
        var name: []u8 = undefined;
        var age: phpz.Zval.Optional = .init;
        try ctx.parse("s|z!", .{ &name.ptr, &name.len, &age.inner });
        self.name = name.ptr;
        self.name_len = name.len;
        if (age.unwrap()) |zv| if (zv.is(.int)) self.safeSetAge(zv.asUnchecked(.int));
    }

    pub fn getName(self: Human, ret: *phpz.Zval) void {
        ret.set(.string, self.name[0 .. self.name_len - 1]);
    }

    pub fn setName(self: *Human, ctx: *phpz.ExecContext) !void {
        var name: []u8 = undefined;
        try ctx.parse("s", .{ &name.ptr, &name.len });
        self.name = name.ptr;
        self.name_len = name.len;
    }

    pub fn getAge(self: Human) i64 {
        return self.age;
    }

    pub fn setAge(self: *Human, ctx: *phpz.ExecContext) !void {
        var age: i64 = undefined;
        try ctx.parse("l", .{&age});
        self.safeSetAge(age);
    }

    inline fn safeSetAge(self: *Human, age: i64) void {
        self.age = if (age > std.math.maxInt(@TypeOf(self.age)))
            std.math.maxInt(@TypeOf(self.age))
        else if (age < std.math.minInt(@TypeOf(self.age)))
            std.math.minInt(@TypeOf(self.age))
        else
            @intCast(age);
    }

    pub fn string(self: Human, ret: *phpz.Zval) !void {
        const result = try std.fmt.allocPrint(gpa, "I am {s}, {d} years old!", .{ self.name[0..self.name_len], self.age });
        defer gpa.free(result);
        ret.set(.string, result);
    }
};

pub const Class = phpz.Class("MyPHPExt\\Human", Human);

comptime {
    Class.method("__construct", .construct);
    Class.method("getName", .getName);
    Class.method("setName", .setName);
    Class.method("getAge", .getAge);
    Class.method("setAge", .setAge);
    Class.method("__toString", .string);
}

const std = @import("std");

const phpz = @import("phpz");
const c = phpz.c;

const gpa = @import("../allocator.zig").gpa;
