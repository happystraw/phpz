const phpz = @import("phpz");

const SerializableValue = struct {
    number: i64 = 0,

    /// PHP: MyPHPExt\Test\SerializableValue::__construct(int $value): void
    pub fn __construct(number: i64) SerializableValue {
        return .{ .number = number };
    }

    /// PHP: MyPHPExt\Test\SerializableValue::value(): int
    pub fn value(self: *const SerializableValue) i64 {
        return self.number;
    }

    /// PHP: MyPHPExt\Test\SerializableValue::__serialize(): array
    pub fn __serialize(self: *const SerializableValue, ctx: phpz.Ctx) void {
        const data = phpz.Zval.Array.init(ctx.retval.ptr(), 1);
        data.set(.int, "value", self.number);
    }

    /// PHP: MyPHPExt\Test\SerializableValue::__unserialize(array $data): void
    pub fn __unserialize(self: *SerializableValue, data: *phpz.zend.Array) !void {
        const value_zval = data.find("value") orelse return error.InvalidSerializedData;
        const stored = phpz.Zval.from(value_zval);
        if (!stored.is(.int)) return error.InvalidSerializedData;
        self.number = stored.asUnchecked(.int);
    }
};

pub const Class = phpz.Class("MyPHPExt\\Test\\SerializableValue", SerializableValue, .{});
