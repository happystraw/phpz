const phpz = @import("phpz");

const SerializableValue = struct {
    number: i64 = 0,

    pub fn __construct(ctx: phpz.Ctx) !SerializableValue {
        const args = try ctx.call.expectArgs(&.{.{ .int = .{} }}, {});
        return .{ .number = args[0] };
    }

    pub fn value(self: *const SerializableValue, ctx: phpz.Ctx) void {
        ctx.ret.set(.int, self.number);
    }

    pub fn __serialize(self: *const SerializableValue, ctx: phpz.Ctx) void {
        const data = phpz.Zval.Array.init(ctx.ret.ptr(), 1);
        data.set(.int, "value", self.number);
    }

    pub fn __unserialize(self: *SerializableValue, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{.{ .array = .{} }}, {});
        const value_zval = args[0].find("value") orelse return error.InvalidSerializedData;
        const stored = phpz.Zval.from(value_zval);
        if (!stored.is(.int)) return error.InvalidSerializedData;
        self.number = stored.asUnchecked(.int);
    }
};

pub const Class = phpz.Class("MyPHPExt\\Test\\SerializableValue", SerializableValue, .{
    .init = .default,
    .serializable = true,
});
