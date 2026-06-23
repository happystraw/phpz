const ExampleAttribute = extern struct {
    /// __construct(string $name, ?string $note = null)
    pub fn construct(self: *ExampleAttribute, ctx: phpz.Ctx) !void {
        const name, const note = try ctx.call.expectArgs(&.{
            .{ .string = .{} },
            .{ .string = .{ .optional = true, .nullable = true } },
        }, {});

        const attr: *Class = .from(.impl, self);
        try attr.updateProperty(.string, "name", name);
        if (note) |val| {
            if (val.asOptional()) |v| {
                try attr.updateProperty(.string, "note", v);
            }
        }
    }
};

pub const Class = phpz.Class("MyPHPExt\\ExampleAttribute", ExampleAttribute);

comptime {
    Class.method("__construct", .construct);
}

const phpz = @import("phpz");
