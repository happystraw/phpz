const std = @import("std");
const phpz = @import("phpz");
const Zval = phpz.Zval;

/// PHP: checkedNamedArguments(int $name, int $age = 2, mixed ...$args): array
pub fn checkedNamedArguments(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgsAllowExtraNamed(&.{
        .{ .int = .{} },
        .{ .int = .{ .optional = true } },
    }, {});
    const result = Zval.Array.empty(ctx.ret.ptr());
    result.set(.int, "name", args[0]);
    result.set(.int, "age", args[1] orelse 2);
    try collect(ctx, result, 2);
}

/// PHP: collectArguments(int $name = 1, int $age = 2, mixed ...$args): array
pub fn collectArguments(ctx: phpz.Ctx) !void {
    try ctx.call.expectArgCount(0, std.math.maxInt(u32));
    const name = try ctx.call.expectArg(1, .{ .int = .{ .optional = true } }, {});
    const age = try ctx.call.expectArg(2, .{ .int = .{ .optional = true } }, {});
    const result = Zval.Array.empty(ctx.ret.ptr());
    result.set(.int, "name", name orelse 1);
    result.set(.int, "age", age orelse 2);
    try collect(ctx, result, 2);
}

/// Used by a generic closure and a registered by-reference variadic function.
pub fn collectAll(ctx: phpz.Ctx) !void {
    try collect(ctx, Zval.Array.empty(ctx.ret.ptr()), 0);
}

fn collect(ctx: phpz.Ctx, result: *Zval.Array, prefix: usize) !void {
    const slots = ctx.call.args();
    for (slots[@min(prefix, slots.len)..]) |*raw| {
        var copy = Zval.raw.undef;
        Zval.raw.copy(&copy, raw);
        errdefer Zval.raw.release(&copy);
        try result.append(.mixed, &copy);
    }
    if (ctx.call.extraNamedArgs()) |named| {
        var it = named.fastIterator();
        while (it.next()) |entry| {
            var copy = Zval.raw.undef;
            Zval.raw.copy(&copy, entry.value);
            result.set(.mixed, entry.key.string, &copy);
        }
    }
}

pub fn parsedSum(ctx: phpz.Ctx) !void {
    var left: phpz.c.zend_long = 0;
    var right: phpz.c.zend_long = 0;
    try ctx.call.parseArgs("ll", .{ &left, &right });
    ctx.ret.set(.int, left +| right);
}

pub fn parsedVariadicCount(ctx: phpz.Ctx) !void {
    var args: ?*phpz.c.zval = null;
    var count: u32 = 0;
    try ctx.call.parseArgs("*", .{ &args, &count });
    ctx.ret.set(.int, count);
}
