const std = @import("std");
const phpz = @import("phpz");
const zend = phpz.zend;
const Zval = phpz.Zval;
const errors = phpz.errors;

const max_build = 1 << 24;

comptime {
    phpz.namedFunctions(.{
        .bench_zig_empty = empty,
        .bench_zig_parse_multi = parseMulti,
        .bench_zig_parse_multi_pp = parseMultiPp,
        .bench_zig_array_sum_fast = arraySumTyped,
        .bench_zig_array_sum_parse = arraySumParse,
        .bench_zig_add = add,
        .bench_zig_muladd = muladd,
        .bench_zig_str_len = strLen,
        .bench_zig_int_to_string = intToString,
        .bench_zig_str_upper = strUpper,
        .bench_zig_array_sum_assoc = arraySumAssoc,
        .bench_zig_array_build = arrayBuild,
        .bench_zig_hash_lookup = hashLookup,
        .bench_zig_array_identity = arrayIdentity,
        .bench_zig_throw = throwException,
        .bench_zig_split = split,
        .bench_zig_counter = counter,
        .bench_zig_invoke = invoke,
    });

    const extension = @import("extension_info");
    phpz.module(.{
        .name = extension.name,
        .version = extension.version,
        .classes = &.{PointClass},
        .globals = Globals,
        .request_startup_fn = resetCounter,
    });
}

fn empty() void {}

fn parseMulti(
    n: i64,
    s: []const u8,
    d: f64,
    b: bool,
    arr: *zend.Array,
    obj: *zend.Object,
    mixed: *Zval,
    opt: ?phpz.Nullable(i64),
) void {
    _ = .{ n, s, d, b, arr, obj, mixed, opt };
}

fn parseMultiPp(ctx: phpz.Ctx) !void {
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
}

fn sumValues(arr: *zend.Array) i64 {
    var sum: i64 = 0;
    arr.eachValue(struct {
        fn callback(zv: *phpz.c.zval, total: *i64) void {
            if (Zval.raw.is(zv, .int)) total.* += Zval.raw.asUnchecked(zv, .int);
        }
    }.callback, .{&sum});
    return sum;
}

fn arraySumTyped(arr: *zend.Array) i64 {
    return sumValues(arr);
}

fn arraySumParse(ctx: phpz.Ctx) !i64 {
    var arr_zv: *phpz.c.zval = undefined;
    try ctx.call.parseArgs("a", .{&arr_zv});
    return sumValues(Zval.raw.asUnchecked(arr_zv, .array));
}

fn add(a: i64, b: i64) i64 {
    return a +% b;
}

fn muladd(a: f64, b: f64, c: f64) f64 {
    return a * b + c;
}

fn strLen(s: []const u8) usize {
    return s.len;
}

fn intToString(n: i64) *zend.String {
    var buffer: [24]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{d}", .{n}) catch unreachable;
    return zend.String.init(text, false);
}

// Zig 0.17 does not auto-vectorize the scalar loop that gcc does, so use @Vector.
fn strUpper(s: []const u8) *zend.String {
    const result = zend.String.alloc(s.len, false);
    const out = result.mutableSlice();
    const lanes = 16;
    const V = @Vector(lanes, u8);
    var i: usize = 0;
    while (i + lanes <= s.len) : (i += lanes) {
        const chunk: V = s[i..][0..lanes].*;
        const lower = chunk -% @as(V, @splat('a')) < @as(V, @splat(26));
        out[i..][0..lanes].* = @select(u8, lower, chunk -% @as(V, @splat('a' - 'A')), chunk);
    }
    for (out[i..s.len], s[i..]) |*dst, ch| dst.* = std.ascii.toUpper(ch);
    return result;
}

fn arraySumAssoc(arr: *zend.Array) i64 {
    var sum: i64 = 0;
    arr.each(struct {
        fn callback(entry: zend.Array.Entry, total: *i64) void {
            switch (entry.key) {
                .string => |key| total.* += @intCast(key.len),
                .int => {},
            }
            if (Zval.raw.is(entry.value, .int)) total.* += Zval.raw.asUnchecked(entry.value, .int);
        }
    }.callback, .{&sum});
    return sum;
}

fn arrayBuild(n: i64) !*zend.Array {
    if (n < 0 or n > max_build) return errors.argumentValueError(1, "must be between 0 and 16777216", .{});
    const count: u32 = @intCast(n);
    var list = zend.Array.ListBuilder.init(count);
    for (0..count) |i| list.appendAssumeCapacity(.int, @intCast(i));
    return list.finish();
}

fn hashLookup(arr: *zend.Array, key: *zend.String) ?*Zval {
    return Zval.from(arr.findStr(key) orelse return null);
}

fn arrayIdentity(arr: *zend.Array) *zend.Array {
    arr.addref();
    return arr;
}

fn throwException(code: i64) !void {
    return errors.throwException(.from(phpz.globals.class.entry("Exception")), "boom", code);
}

fn split(ctx: phpz.Ctx, s: []const u8, separator: []const u8) !void {
    if (separator.len == 0) return errors.argumentValueError(2, "cannot be empty", .{});
    const result = Zval.Array.empty(ctx.retval.ptr());
    var parts = std.mem.splitSequence(u8, s, separator);
    while (parts.next()) |part| try result.append(.string, part);
}

const Globals = phpz.ModuleGlobals(struct { counter: i64 = 0 });

fn resetCounter() !void {
    Globals.get().counter = 0;
}

fn counter() i64 {
    const globals = Globals.get();
    globals.counter += 1;
    return globals.counter;
}

fn invoke(ctx: phpz.Ctx, callback: *zend.Callable, arg: *Zval) !void {
    try callback.call(ctx.retval.ptr(), .{arg.ptr().*}, null);
}

const Point = struct {
    x: f64 = 0,
    y: f64 = 0,

    pub fn __construct(x: f64, y: f64) Point {
        return .{ .x = x, .y = y };
    }

    pub fn length(self: *const Point) f64 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }

    pub fn translate(self: *Point, dx: f64, dy: f64) void {
        self.x += dx;
        self.y += dy;
    }
};

const PointClass = phpz.Class("BenchZigPoint", Point, .{});
