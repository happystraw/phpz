const User = extern struct {
    pub fn register(impl: anytype) *phpz.ClassEntry {
        return .from(impl(AbstractEntity.entry.ptr(), c.zend_ce_stringable));
    }

    pub fn construct(self: *User, ctx: phpz.Ctx) !void {
        var name: []u8 = undefined;
        var age: phpz.Zval.Optional = .init;
        try ctx.call.parse("s|z!", .{ &name.ptr, &name.len, &age.ptr });

        const user: *Class = .from(.impl, self);
        try user.updateProperty(.string, "name", name);
        if (age.unwrap()) |zv| {
            if (zv.is(.int)) {
                try user.updateProperty(.int, "age", zv.asUnchecked(.int));
            }
        }
        try user.call("onload", null, .{});
    }

    pub fn handle(self: *User, ctx: phpz.Ctx) !void {
        var zv: *c.zval = undefined;
        try ctx.call.parse("z", .{&zv});

        const user: *Class = .from(.impl, self);
        const name = blk: {
            const name_zv = try user.property("name", false);
            if (name_zv.is(.undef)) return error.NamePropertyMissing;
            break :blk name_zv.asUnchecked(.string);
        };
        const age: i64 = if ((try user.property("age", false)).is(.undef))
            0
        else
            (try user.property("age", false)).asUnchecked(.int);

        var buf: [256]u8 = undefined;
        if (phpz.Zval.native.is(zv, .int)) {
            const result = try std.fmt.bufPrint(&buf, "{s}({d}).handle({d})\n", .{ name, age, phpz.Zval.native.asUnchecked(zv, .int) });
            buf[result.len] = 0;
            _ = phpz.printf(buf[0..result.len :0], .{});
        } else if (phpz.Zval.native.is(zv, .string)) {
            const s = phpz.Zval.native.asUnchecked(zv, .string);
            const result = try std.fmt.bufPrint(&buf, "{s}({d}).handle({s})\n", .{ name, age, s });
            buf[result.len] = 0;
            _ = phpz.printf(buf[0..result.len :0], .{});
        }
    }

    pub fn getId(self: *const User, ctx: phpz.Ctx) void {
        _ = self;
        ctx.ret.set(.int, 9527);
    }

    pub fn toString(self: *const User, ctx: phpz.Ctx) !void {
        const user: *Class = .from(.impl, @constCast(self));
        const name = blk: {
            const name_zv = try user.property("name", false);
            break :blk if (name_zv.is(.undef)) "" else name_zv.asUnchecked(.string);
        };

        const result = try std.fmt.allocPrint(gpa, "User({s})", .{name});
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
