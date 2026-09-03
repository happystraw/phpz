/// PHP: MyPHPExt\Tag::__construct(string $name, ?string $description = null): void
pub fn __construct(ctx: phpz.Ctx) !void {
    const name, const description = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
        .{ .string = .{ .optional = true, .nullable = true } },
    }, {});

    const tag = ctx.call.this().?;
    try tag.setProperty(.string, "name", name);
    if (description) |provided| {
        switch (provided) {
            .null => try tag.setProperty(.null, "description", {}),
            .value => |value| try tag.setProperty(.string, "description", value),
        }
    } else {
        try tag.setProperty(.null, "description", {});
    }
}

pub const Class = phpz.Class("MyPHPExt\\Tag", @This(), .{});

const phpz = @import("phpz");
