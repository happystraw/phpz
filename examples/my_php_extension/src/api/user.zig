const Impl = extern struct {
    pub fn register(impl: anytype) *phpz.ClassEntry {
        return .from(impl(
            entity.Class.entry.ptr(),
            phpz.globals.class.entry("Stringable"),
        ));
    }

    /// PHP: MyPHPExt\User::__construct(int $id, string $name, ?int $age = null, MyPHPExt\Role $role = MyPHPExt\Role::User, MyPHPExt\Status $status = MyPHPExt\Status::Active): void
    pub fn construct(self: *Impl, ctx: phpz.Ctx) !void {
        const id, const name, const age, const role_arg, const status_arg = try ctx.call.expectArgs(
            &.{
                .{ .int = .{} },
                .{ .string = .{} },
                .{ .int = .{ .optional = true, .nullable = true } },
                .{ .object = .{ .optional = true, .instanceof = true } },
                .{ .object = .{ .optional = true, .instanceof = true } },
            },
            .{ {}, {}, {}, .{ .type = role.Class.entry }, .{ .type = status.Class.entry } },
        );

        const user: *Class = .from(.impl, self);
        try user.updateProperty(.int, "id", id);
        try user.updateProperty(.string, "name", name);
        if (age) |provided| {
            switch (provided) {
                .null => try user.updateProperty(.null, "age", {}),
                .value => |value| try user.updateProperty(.int, "age", value),
            }
        } else {
            try user.updateProperty(.null, "age", {});
        }

        const role_value = role_arg orelse
            (role.Class.entry.getEnumCase("User") orelse unreachable);
        const status_value = status_arg orelse
            (status.Class.entry.getEnumCase("Active") orelse unreachable);
        try user.updateProperty(.object, "role", role_value);
        try user.updateProperty(.object, "status", status_value);
    }

    /// PHP: MyPHPExt\User::label(): string
    pub fn label(self: *const Impl, ctx: phpz.Ctx) !void {
        try returnName(self, ctx);
    }

    /// PHP: MyPHPExt\User::__toString(): string
    pub fn toString(self: *const Impl, ctx: phpz.Ctx) !void {
        try returnName(self, ctx);
    }

    fn returnName(self: *const Impl, ctx: phpz.Ctx) !void {
        const user: *Class = .from(.impl, @constCast(self));
        var scratch = phpz.Zval.raw.undef;
        defer phpz.Zval.raw.tryRelease(&scratch);

        const name = try user.property("name", false, &scratch);
        ctx.ret.set(.string, phpz.Zval.raw.asUnchecked(name.ptr(), .string));
    }
};

pub const Class = phpz.Class("MyPHPExt\\User", Impl);

comptime {
    Class.method("__construct", .construct);
    Class.method("label", .label);
    Class.method("__toString", .toString);
}

const phpz = @import("phpz");
const entity = @import("entity.zig");
const role = @import("role.zig");
const status = @import("status.zig");
