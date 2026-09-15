const phpz = @import("phpz");

pub fn separateArray(ctx: phpz.Ctx) !void {
    _ = try ctx.call.expectArgs(&.{.{ .array = .{} }}, {});
    ctx.retval.set(.mixed, ctx.call.arg(1));
    const result = phpz.Zval.Array.fromUnchecked(ctx.retval.ptr());
    result.separate();
    result.set(.int, "count", 1);
    try result.setAt(.int, 0, 2);
    try result.append(.int, 3);
}

pub fn copyArray(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{ .{ .array = .{} }, .{ .array = .{} } }, {});
    const result = args[0].dupe();
    ctx.retval.set(.array, result);
    result.copy(args[1]);
}

pub fn mergeArray(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{ .{ .array = .{} }, .{ .array = .{} }, .{ .bool = .{} } }, {});
    const result = args[0].dupe();
    ctx.retval.set(.array, result);
    result.merge(args[1], args[2]);
}

pub fn compareArrays(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .array = .{} }, .{ .array = .{} }, .{ .bool = .{} }, .{ .bool = .{} },
    }, {});
    const result = if (args[3])
        try args[0].compare(args[1], compareIdentical, args[2])
    else
        try args[0].compare(args[1], compareValues, args[2]);
    ctx.retval.set(.int, result);
}

fn compareValues(left: *const phpz.c.zval, right: *const phpz.c.zval) c_int {
    return phpz.c.zend_compare(@constCast(left), @constCast(right));
}

fn compareIdentical(left: *const phpz.c.zval, right: *const phpz.c.zval) c_int {
    const l = @constCast(left);
    const r = @constCast(right);
    const a = if (phpz.Zval.raw.is(l, .reference)) phpz.Zval.raw.asUnchecked(l, .reference).val() else l;
    const b = if (phpz.Zval.raw.is(r, .reference)) phpz.Zval.raw.asUnchecked(r, .reference).val() else r;
    return @intFromBool(!phpz.c.zend_is_identical(a, b));
}
