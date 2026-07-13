const Impl = extern struct {
    pub fn register(impl: anytype) *phpz.ClassEntry {
        return .from(impl(identifiable.Class.entry.ptr()));
    }

    /// PHP: MyPHPExt\Entity::__construct(int $id): void
    pub fn construct(self: *Impl, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{} },
        }, {});

        const entity: *Class = .from(.impl, self);
        try entity.updateProperty(.int, "id", args[0]);
    }

    /// PHP: MyPHPExt\Entity::getId(): int
    pub fn getId(self: *const Impl, ctx: phpz.Ctx) !void {
        const entity: *Class = .from(.impl, @constCast(self));
        var scratch = phpz.Zval.raw.undef;
        defer phpz.Zval.raw.tryDtor(&scratch);

        const id = try entity.property("id", false, &scratch);
        ctx.ret.set(.int, phpz.Zval.raw.asUnchecked(id.ptr(), .int));
    }
};

pub const Class = phpz.Class("MyPHPExt\\Entity", Impl);

comptime {
    Class.method("__construct", .construct);
    Class.method("getId", .getId);
}

const phpz = @import("phpz");
const identifiable = @import("identifiable.zig");
