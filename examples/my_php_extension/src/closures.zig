const phpz = @import("phpz");
const Zval = phpz.Zval;

/// PHP: {closure}(...$args) — accepts two integers and returns their sum.
fn sum(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{ .{ .int = .{} }, .{ .int = .{} } }, {});
    ctx.ret.set(.int, args[0] +| args[1]);
}

/// PHP: MyPHPExt\makeSumClosure(): Closure
pub fn makeSumClosure(ctx: phpz.Ctx) !void {
    try ctx.call.expectNoArgs();
    phpz.closure.fromFn(sum, ctx.ret);
}

const Counter = struct {
    value: i64 = 0,
    held: phpz.c.zval = Zval.raw.undef,

    /// PHP: MyPHPExt\ClosureCounter::__construct(): void
    pub fn __construct() !Counter {
        return phpz.errors.throwError(null, "Cannot directly construct MyPHPExt\\ClosureCounter", .{});
    }

    /// PHP: MyPHPExt\ClosureCounter::__invoke(int $step = 1): int
    pub fn __invoke(self: *Counter, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{ .optional = true } },
        }, {});
        self.value +|= args[0] orelse 1;
        ctx.ret.set(.int, self.value);
    }

    fn deinit(self: *Counter) void {
        Zval.raw.release(&self.held);
    }

    fn gc(self: *Counter, buffer: *phpz.GcBuffer) void {
        buffer.add(.from(&self.held));
    }
};

pub const CounterClass = phpz.Class("MyPHPExt\\ClosureCounter", Counter, .{
    .init = .default,
    .deinit = Counter.deinit,
    .gc = Counter.gc,
});

/// PHP: MyPHPExt\makeCounter(int $start = 0, mixed $held = null): Closure
pub fn makeCounter(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .int = .{ .optional = true } },
        .{ .mixed = .{ .optional = true } },
    }, {});
    const owner = CounterClass.create();
    defer owner.object().release();
    const backing = owner.backing().?;
    backing.value = args[0] orelse 0;
    if (args[1]) |held| Zval.raw.copy(&backing.held, held.ptr());
    const invoke = phpz.zend.Function.findMethod(CounterClass.entry, "__invoke").?;
    try invoke.toClosure(ctx.ret, .{ .object = owner.object() });
}

const Reference = struct {
    value: phpz.c.zval = Zval.raw.undef,

    /// PHP: MyPHPExt\ClosureRef::__construct(): void
    pub fn __construct() !Reference {
        return phpz.errors.throwError(null, "Cannot directly construct MyPHPExt\\ClosureRef", .{});
    }

    /// PHP: MyPHPExt\ClosureRef::__invoke(): mixed (returns by reference)
    pub fn __invoke(self: *const Reference, ctx: phpz.Ctx) !void {
        try ctx.call.expectNoArgs();
        // Returning a reference adds an owned reference to the return slot.
        Zval.raw.copy(ctx.ret.ptr(), @constCast(&self.value));
    }

    fn deinit(self: *Reference) void {
        Zval.raw.release(&self.value);
    }

    fn gc(self: *Reference, buffer: *phpz.GcBuffer) void {
        buffer.add(.from(&self.value));
    }
};

pub const ReferenceClass = phpz.Class("MyPHPExt\\ClosureRef", Reference, .{
    .init = .default,
    .deinit = Reference.deinit,
    .gc = Reference.gc,
});

/// PHP: MyPHPExt\makeReference(mixed &$value): Closure
pub fn makeReference(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .reference = .{ .result = .zval } },
    }, {});
    const owner = ReferenceClass.create();
    defer owner.object().release();
    Zval.raw.copy(&owner.backing().?.value, args[0].ptr());
    const invoke = phpz.zend.Function.findMethod(ReferenceClass.entry, "__invoke").?;
    try invoke.toClosure(ctx.ret, .{ .object = owner.object() });
}

pub const classes = .{ CounterClass, ReferenceClass };
