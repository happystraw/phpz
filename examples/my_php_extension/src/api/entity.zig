pub fn register(impl: anytype) *phpz.ClassEntry {
    return .from(impl(identifiable.Class.entry.ptr()));
}

/// PHP: MyPHPExt\Entity::__construct(int $id): void
pub fn construct(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .int = .{} },
    }, {});

    const entity = ctx.call.thisObject().?;
    try entity.setProperty(.int, "id", args[0]);
}

/// PHP: MyPHPExt\Entity::getId(): int
pub fn getId(ctx: phpz.Ctx) !void {
    const entity = ctx.call.thisObject().?;
    var scratch = phpz.Zval.raw.undef;
    defer phpz.Zval.raw.tryRelease(&scratch);

    const id = try entity.property("id", false, &scratch);
    ctx.ret.set(.int, phpz.Zval.raw.asUnchecked(id.ptr(), .int));
}

pub const Class = phpz.SimpleClass("MyPHPExt\\Entity", @This());

comptime {
    Class.method("__construct", construct);
    Class.method("getId", getId);
}

const phpz = @import("phpz");

const identifiable = @import("identifiable.zig");
