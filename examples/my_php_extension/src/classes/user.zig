const User = extern struct {
    name: [*]u8,
    name_len: usize,
    age: i64 = 0,
    has_age: bool = false,

    pub fn register(impl: anytype) *phpz.ClassEntry {
        return .from(impl(AbstractEntity.entry.ptr(), c.zend_ce_stringable));
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
        var zv: *c.zval = undefined;
        try ctx.call.parse("z", .{&zv});

        var buf: [256]u8 = undefined;
        if (phpz.Zval.native.is(zv, .int)) {
            const result = try std.fmt.bufPrint(&buf, "{s}({d}).handle({d})\n", .{ self.name[0..self.name_len], self.age, phpz.Zval.native.asUnchecked(zv, .int) });
            buf[result.len] = 0;
            _ = phpz.printf(buf[0..result.len :0], .{});
        } else if (phpz.Zval.native.is(zv, .string)) {
            const s = phpz.Zval.native.asUnchecked(zv, .string);
            const result = try std.fmt.bufPrint(&buf, "{s}({d}).handle({s})\n", .{ self.name[0..self.name_len], self.age, s });
            buf[result.len] = 0;
            _ = phpz.printf(buf[0..result.len :0], .{});
        }
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
