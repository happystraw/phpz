const Impl = struct {
    current_value: i64,

    /// PHP: MyPHPExt\Counter::__construct(int $value = 0): void
    pub fn construct(self: *Impl, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{ .optional = true } },
        }, {});
        self.current_value = args[0] orelse 0;
    }

    /// PHP: MyPHPExt\Counter::increment(int $by = 1): int
    pub fn increment(self: *Impl, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{ .optional = true } },
        }, {});
        self.current_value +|= args[0] orelse 1;
        ctx.ret.set(.int, self.current_value);
    }

    /// PHP: MyPHPExt\Counter::decrement(int $by = 1): int
    pub fn decrement(self: *Impl, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{ .optional = true } },
        }, {});
        self.current_value -|= args[0] orelse 1;
        ctx.ret.set(.int, self.current_value);
    }

    /// PHP: MyPHPExt\Counter::value(): int
    pub fn value(self: *const Impl, ctx: phpz.Ctx) void {
        ctx.ret.set(.int, self.current_value);
    }

    /// PHP: MyPHPExt\Counter::reset(int $value = 0): void
    pub fn reset(self: *Impl, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{ .optional = true } },
        }, {});
        self.current_value = args[0] orelse 0;
    }
};

pub const Class = phpz.Class("MyPHPExt\\Counter", Impl);

comptime {
    Class.method("__construct", .construct);
    Class.method("increment", .increment);
    Class.method("decrement", .decrement);
    Class.method("value", .value);
    Class.method("reset", .reset);
}

const phpz = @import("phpz");
