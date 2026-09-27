fn register(register_fn: anytype) *phpz.ClassEntry {
    return register_fn(.{identifiable.Class.entry.ptr()});
}

/// PHP: MyPHPExt\Entity::__construct(int $id): void
pub fn __construct(ctx: phpz.Ctx, id: i64) !void {
    const entity = ctx.call.this().?;
    try entity.setProperty(.int, "id", id);
}

/// PHP: MyPHPExt\Entity::getId(): int
pub fn getId(ctx: phpz.Ctx) !i64 {
    const entity = ctx.call.this().?;
    var scratch = phpz.Zval.raw.undef;
    defer phpz.Zval.raw.tryRelease(&scratch);

    const id = try entity.property("id", false, &scratch);
    return phpz.Zval.raw.asUnchecked(id.ptr(), .int);
}

pub const Class = phpz.Class("MyPHPExt\\Entity", @This(), .{ .register = register });

const phpz = @import("phpz");

const identifiable = @import("identifiable.zig");
