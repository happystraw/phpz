fn register(register_fn: anytype) *phpz.ClassEntry {
    return register_fn(.{
        entity.Class.entry.ptr(),
        phpz.globals.class.entry("Stringable"),
    });
}

/// PHP: MyPHPExt\User::__construct(int $id, string $name, ?int $age = null, MyPHPExt\Role $role = MyPHPExt\Role::User, MyPHPExt\Status $status = MyPHPExt\Status::Active): void
pub fn __construct(ctx: phpz.Ctx) !void {
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

    const user = ctx.call.this().?;
    try user.setProperty(.int, "id", id);
    try user.setProperty(.string, "name", name);
    if (age) |provided| {
        switch (provided) {
            .null => try user.setProperty(.null, "age", {}),
            .value => |value| try user.setProperty(.int, "age", value),
        }
    } else {
        try user.setProperty(.null, "age", {});
    }

    const role_value = role_arg orelse
        (role.Class.entry.getEnumCase("User") orelse unreachable);
    const status_value = status_arg orelse
        (status.Class.entry.getEnumCase("Active") orelse unreachable);
    try user.setProperty(.object, "role", role_value);
    try user.setProperty(.object, "status", status_value);
}

/// PHP: MyPHPExt\User::label(): string
/// PHP: MyPHPExt\User::__toString(): string
pub fn label(ctx: phpz.Ctx) !void {
    const user = ctx.call.this().?;
    var scratch = phpz.Zval.raw.undef;
    defer phpz.Zval.raw.tryRelease(&scratch);

    const name = try user.property("name", false, &scratch);
    ctx.ret.set(.string, phpz.Zval.raw.asUnchecked(name.ptr(), .string));
}

pub const Class = phpz.Class("MyPHPExt\\User", @This(), .{ .register = register });

const phpz = @import("phpz");

const entity = @import("entity.zig");
const role = @import("role.zig");
const status = @import("status.zig");
