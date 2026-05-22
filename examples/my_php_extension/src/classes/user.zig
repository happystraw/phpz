const User = extern struct {
    name: [*]u8,
    name_len: usize,
    age: i64 = 0,
    has_age: bool = false,

    pub fn register(impl: anytype) *phpz.ClassEntry {
        return impl(AbstractEntity.entry, c.zend_ce_stringable);
    }

    pub fn construct(self: *User, ctx: phpz.Ctx) !void {
        var name: []u8 = undefined;
        var age: phpz.Zval.Optional = .init;
        try ctx.call.parse("s|z!", .{ &name.ptr, &name.len, &age.ptr });

        const name_copy = try gpa.dupe(u8, name);
        self.name = name_copy.ptr;
        self.name_len = name_copy.len;

        const wrapper: *Class = .from(.impl, self);
        wrapper.updateProperty(.string, "name", name);
        if (age.unwrap()) |zv| {
            self.age = if (zv.is(.int)) zv.asUnchecked(.int) else 0;
            self.has_age = true;
            wrapper.updateProperty(.int, "age", self.age);
        }
        try wrapper.call("onload", .{}, null);
    }

    pub fn deinit(self: *User) void {
        gpa.free(self.name[0..self.name_len]);
    }

    pub fn handle(self: *User, ctx: phpz.Ctx) !void {
        _ = self;
        _ = ctx;
    }

    pub fn getId(self: *const User, ctx: phpz.Ctx) void {
        _ = self;
        ctx.ret.set(.int, 9527);
    }

    pub fn toString(self: *const User, ctx: phpz.Ctx) !void {
        const result = try std.fmt.allocPrint(gpa, "User({s})", .{self.name[0..self.name_len]});
        defer gpa.free(result);
        ctx.ret.set(.string, result);
    }
};

pub const Class = phpz.Class("MyPHPExt\\User", User);

comptime {
    Class.method("__construct", .construct);
    Class.method("handle", .handle);
    Class.method("getId", .getId);
    Class.method("__toString", .toString);
}

const std = @import("std");

const phpz = @import("phpz");
const c = phpz.c;

const gpa = @import("../allocator.zig").gpa;
const AbstractEntity = @import("abstract_entity.zig").Class;
