const phpz = @import("phpz");

pub fn separateArray(ctx: phpz.Ctx, source: *phpz.zend.Array) !void {
    if (!source.isImmutable()) source.addref();
    ctx.retval.set(.array, source);
    const result = try ctx.retval.array();
    result.separate();
    result.set(.int, "count", 1);
    try result.setAt(.int, 0, 2);
    try result.append(.int, 3);
}

pub fn copyArray(ctx: phpz.Ctx, target: *phpz.zend.Array, source: *phpz.zend.Array) void {
    const result = target.dupe();
    ctx.retval.set(.array, result);
    result.copy(source);
}

pub fn mergeArray(ctx: phpz.Ctx, target: *phpz.zend.Array, source: *phpz.zend.Array, overwrite: bool) void {
    const result = target.dupe();
    ctx.retval.set(.array, result);
    result.merge(source, overwrite);
}

pub fn compareArrays(left: *phpz.zend.Array, right: *phpz.zend.Array, ordered: bool, identical: bool) !i64 {
    return if (identical)
        try left.compare(right, compareIdentical, ordered)
    else
        try left.compare(right, compareValues, ordered);
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
