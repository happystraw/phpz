const Human = extern struct {
    name: [*]u8,
    name_len: usize,
    age: u8 = 0,

    pub fn register(impl: anytype) *phpz.ClassEntry {
        return impl(c.zend_ce_stringable);
    }

    pub fn construct(self: *Human, frame: *phpz.CallFrame) !void {
        var name: []u8 = undefined;
        var age: phpz.Zval.Optional = .init;
        try frame.parse("s|z!", .{ &name.ptr, &name.len, &age.ptr });
        self.name = name.ptr;
        self.name_len = name.len;
        if (age.unwrap()) |zv| if (zv.is(.int))
            self.safeSetAge(zv.asUnchecked(.int))
        else
            try errors.argumentTypeError(2, "must be type int, %s given", .{@tagName(zv.kind()).ptr});
    }

    pub fn getName(self: *const Human, ret: *phpz.Zval) void {
        ret.set(.string, self.name[0 .. self.name_len - 1]);
    }

    pub fn setName(self: *Human, frame: *phpz.CallFrame) !void {
        var name: []u8 = undefined;
        try frame.parse("s", .{ &name.ptr, &name.len });
        self.name = name.ptr;
        self.name_len = name.len;
    }

    pub fn getAge(self: *const Human, ret: *phpz.Zval) void {
        ret.set(.int, self.age);
    }

    pub fn setAge(self: *Human, frame: *phpz.CallFrame) !void {
        var age: i64 = undefined;
        try frame.parse("l", .{&age});
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

    pub fn toString(self: *const Human, ret: *phpz.Zval) !void {
        const result = try std.fmt.allocPrint(gpa, "I am {s}, {d} years old!", .{ self.name[0..self.name_len], self.age });
        defer gpa.free(result);
        ret.set(.string, result);
    }

    pub fn species(ret: *phpz.Zval) void {
        ret.set(.string, "Homo sapiens");
    }
};

pub const Class = phpz.Class("MyPHPExt\\Human", Human);

comptime {
    Class.method("__construct", .construct);
    Class.method("getName", .getName);
    Class.method("setName", .setName);
    Class.method("getAge", .getAge);
    Class.method("setAge", .setAge);
    Class.method("__toString", .toString);
    Class.method("species", .species);
}

const std = @import("std");

const phpz = @import("phpz");
const c = phpz.c;
const errors = phpz.errors;

const gpa = @import("../allocator.zig").gpa;
