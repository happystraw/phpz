const Impl = extern struct {
    /// PHP: MyPHPExt\Tag::__construct(string $name, ?string $description = null): void
    pub fn construct(self: *Impl, ctx: phpz.Ctx) !void {
        const name, const description = try ctx.call.expectArgs(&.{
            .{ .string = .{} },
            .{ .string = .{ .optional = true, .nullable = true } },
        }, {});

        const tag: *Class = .from(.impl, self);
        try tag.updateProperty(.string, "name", name);
        if (description) |provided| {
            switch (provided) {
                .null => try tag.updateProperty(.null, "description", {}),
                .value => |value| try tag.updateProperty(.string, "description", value),
            }
        } else {
            try tag.updateProperty(.null, "description", {});
        }
    }
};

pub const Class = phpz.Class("MyPHPExt\\Tag", Impl);

comptime {
    Class.method("__construct", .construct);
}

const phpz = @import("phpz");
