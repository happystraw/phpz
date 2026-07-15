const phpz = @import("phpz");

comptime {
    // 1. Empty function
    phpz.function("bench_zig_empty", benchEmpty);

    // 2. Multi-parameter parsing — expect style
    phpz.function("bench_zig_parse_multi", benchParseMulti);

    // 2b. Multi-parameter parsing — parse() style
    phpz.function("bench_zig_parse_multi_pp", benchParseMultiPp);

    // 3. Array sum — expect style
    phpz.function("bench_zig_array_sum_fast", benchArraySumExpect);

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

// ── 2. Multi-param expect ───────────────────────────────────────────
// Covers: long, string, double, bool, array, object, mixed, ?int = null (optional + nullable)

fn benchParseMulti(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .int = .{} },
        .{ .string = .{} },
        .{ .float = .{} },
        .{ .bool = .{} },
        .{ .array = .{} },
        .{ .object = .{} },
        .{ .mixed = .{} },
        .{ .int = .{ .optional = true, .nullable = true } },
    }, {});
    _ = &args;
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

// ── 3. Array sum expect ─────────────────────────────────────────────

fn benchArraySumExpect(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{.{ .array = .{} }}, {});
    const arr = args[0];

    var sum: i64 = 0;
    arr.eachValue(&sum, struct {
        fn body(zv: *phpz.c.zval, s: *i64) void {
            if (phpz.Zval.raw.is(zv, .int)) {
                s.* += phpz.Zval.raw.asUnchecked(zv, .int);
            }
        }
    }.body);

    ctx.ret.set(.int, sum);
}

// ── 3b. Array sum parse ─────────────────────────────────────────────

fn benchArraySumParse(ctx: phpz.Ctx) !void {
    var arr_zv: *phpz.c.zval = undefined;
    try ctx.call.parseArgs("a", .{&arr_zv});
    const arr = phpz.Zval.raw.asUnchecked(arr_zv, .array);

    var sum: i64 = 0;
    arr.eachValue(&sum, struct {
        fn body(zv: *phpz.c.zval, s: *i64) void {
            if (phpz.Zval.raw.is(zv, .int)) {
                s.* += phpz.Zval.raw.asUnchecked(zv, .int);
            }
        }
    }.body);

    ctx.ret.set(.int, sum);
}
