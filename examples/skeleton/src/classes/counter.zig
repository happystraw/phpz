const phpz = @import("phpz");

/// class Counter
pub const Counter = extern struct {
    n: i64,

    /// public function __construct(int $n = 0): void
    pub fn construct(self: *Counter, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{ .optional = true } },
        }, {});
        self.n = args[0] orelse 0;
    }

    /// public function add(int $n): void
    pub fn add(self: *Counter, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{} },
        }, {});
        self.n +|= args[0];
    }

    /// public function dec(int $n): void
    pub fn dec(self: *Counter, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{} },
        }, {});
        self.n -|= args[0];
    }

    /// public function value(): int
    pub fn value(self: Counter, ctx: phpz.Ctx) void {
        ctx.ret.set(.int, self.n);
    }
};

pub const Class = phpz.Class("Counter", Counter);

comptime {
    Class.method("__construct", .construct);
    Class.method("add", .add);
    Class.method("dec", .dec);
    Class.method("value", .value);
}
