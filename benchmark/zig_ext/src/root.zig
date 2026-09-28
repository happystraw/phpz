const phpz = @import("phpz");

comptime {
    // 1. Empty function
    phpz.function("bench_zig_empty", benchEmpty);

    // 2. Multi-parameter parsing — typed signature
    phpz.function("bench_zig_parse_multi", benchParseMulti);

    // 2b. Multi-parameter parsing — parse() style
    phpz.function("bench_zig_parse_multi_pp", benchParseMultiPp);

    // 3. Array sum — typed signature
    phpz.function("bench_zig_array_sum_fast", benchArraySumTyped);

    // 3b. Array sum — parse style
    phpz.function("bench_zig_array_sum_parse", benchArraySumParse);

    const extension = @import("extension_info");

    phpz.module(.{
        .name = extension.name,
        .version = extension.version,
    });
}

// ── 1. Empty ────────────────────────────────────────────────────────

fn benchEmpty() void {}

// ── 2. Multi-param typed signature ──────────────────────────────────
// Covers: long, string, double, bool, array, object, mixed, ?int = null (optional + nullable)

fn benchParseMulti(
    n: i64,
    s: []const u8,
    d: f64,
    b: bool,
    arr: *phpz.zend.Array,
    obj: *phpz.zend.Object,
    mixed: *phpz.Zval,
    opt: ?phpz.Nullable(i64),
) void {
    _ = n;
    _ = s;
    _ = d;
    _ = b;
    _ = arr;
    _ = obj;
    _ = mixed;
    _ = opt;
}

// ── 2b. Multi-param parse() ─────────────────────────────────────────
// Covers: l=long, s=string, d=double, b=bool, a=array, o=object, z=zval, |l=optional long

fn benchParseMultiPp(ctx: phpz.Ctx) !void {
    var n: i64 = undefined;
    var s: []u8 = undefined;
    var d: f64 = undefined;
    var b: bool = undefined;
    var arr: *phpz.c.zval = undefined;
    var obj: *phpz.c.zval = undefined;
    var mixed: *phpz.c.zval = undefined;
    var opt: i64 = 0;
    var opt_is_null: bool = undefined;
    try ctx.call.parseArgs("lsdbaoz|l!", .{ &n, &s.ptr, &s.len, &d, &b, &arr, &obj, &mixed, &opt, &opt_is_null });
    _ = &n;
    _ = &s;
    _ = &d;
    _ = &b;
    _ = &arr;
    _ = &obj;
    _ = &mixed;
    _ = &opt;
    _ = &opt_is_null;
}

// ── 3. Array sum typed signature ────────────────────────────────────

fn benchArraySumTyped(arr: *phpz.zend.Array) i64 {
    var sum: i64 = 0;
    arr.eachValue(struct {
        fn callback(zv: *phpz.c.zval, s: *i64) void {
            if (phpz.Zval.raw.is(zv, .int)) {
                s.* += phpz.Zval.raw.asUnchecked(zv, .int);
            }
        }
    }.callback, .{&sum});

    return sum;
}

// ── 3b. Array sum parse ─────────────────────────────────────────────

fn benchArraySumParse(ctx: phpz.Ctx) !i64 {
    var arr_zv: *phpz.c.zval = undefined;
    try ctx.call.parseArgs("a", .{&arr_zv});
    const arr = phpz.Zval.raw.asUnchecked(arr_zv, .array);

    var sum: i64 = 0;
    arr.eachValue(struct {
        fn callback(zv: *phpz.c.zval, s: *i64) void {
            if (phpz.Zval.raw.is(zv, .int)) {
                s.* += phpz.Zval.raw.asUnchecked(zv, .int);
            }
        }
    }.callback, .{&sum});

    return sum;
}
