const User = extern struct {
    pub fn register(impl: anytype) *phpz.ClassEntry {
        return .from(impl(AbstractEntity.entry.ptr(), phpz.globals.class.entry("Stringable")));
    }

    /// __construct(string $name, int|null $age = null)
    pub fn construct(self: *User, ctx: phpz.Ctx) !void {
        const name, const age = try ctx.call.expectArgs(&.{
            .{ .string = .{} },
            .{ .int = .{ .optional = true, .nullable = true } },
        }, {});

        const user: *Class = .from(.impl, self);

        try user.updateProperty(.string, "name", name);
        if (age) |val| if (val.asOptional()) |v|
            try user.updateProperty(.int, "age", v);

        try user.call("onload", null, .{});
    }

    /// handle(string|int $id): void
    pub fn handle(self: *User, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .mixed = .{ .unions = &.{ .int, .string } } },
        }, {});
        const id = args[0];

        const user: *Class = .from(.impl, self);
        const name = blk: {
            var scratch = phpz.Zval.native.undef;
            const prop = try user.property("name", false, &scratch);
            defer phpz.Zval.native.tryDtor(&scratch);
            break :blk if (prop.is(.undef)) "" else prop.asUnchecked(.string);
        };
        const age: i64 = blk: {
            var scratch = phpz.Zval.native.undef;
            const prop = try user.property("age", false, &scratch);
            defer phpz.Zval.native.tryDtor(&scratch);
            break :blk if (prop.is(.undef)) 0 else prop.asUnchecked(.int);
        };

        var buf: [256]u8 = undefined;
        switch (id) {
            .int => |i| {
                const result = try std.fmt.bufPrintSentinel(&buf, "{s}({d}).handle({d})\n", .{ name, age, i }, 0);
                _ = phpz.printf(buf[0..result.len :0], .{});
            },
            .string => |s| {
                const result = try std.fmt.bufPrintSentinel(&buf, "{s}({d}).handle({s})\n", .{ name, age, s }, 0);
                _ = phpz.printf(buf[0..result.len :0], .{});
            },
        }
    }

    /// getId(): int
    pub fn getId(self: *const User, ctx: phpz.Ctx) void {
        _ = self;
        ctx.ret.set(.int, 9527);
    }

    /// __toString(): string
    pub fn toString(self: *const User, ctx: phpz.Ctx) !void {
        const user: *Class = .from(.impl, @constCast(self));
        const name = blk: {
            var scratch = phpz.Zval.native.undef;
            const prop = try user.property("name", false, &scratch);
            defer phpz.Zval.native.tryDtor(&scratch);
            break :blk if (prop.is(.undef)) "" else prop.asUnchecked(.string);
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
