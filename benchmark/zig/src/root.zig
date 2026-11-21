const std = @import("std");
const phpz = @import("phpz");
const extension = @import("extension_info");

comptime {
    phpz.namedFunctions(.{
        .bench_call = benchCall,
        .bench_args = benchArgs,
        .bench_sum = benchSum,
        .bench_build = benchBuild,
        .bench_invoke = benchInvoke,
        .bench_lookup = benchLookup,
        .bench_cow = benchCow,
        .bench_split = benchSplit,
        .bench_upper = benchUpper,
        .bench_length = benchLength,
    });
    phpz.module(.{
        .name = extension.name,
        .version = extension.version,
        .classes = &.{Point},
    });
}

fn benchCall() void {}

fn benchArgs(number: i64, text: []const u8, decimal: f64, flag: bool, optional: ?phpz.Nullable(i64)) i64 {
    const base = number ^ @as(i64, @intCast(text.len)) ^ (if (decimal > 0) @as(i64, 16) else 0) ^
        (if (flag) @as(i64, 32) else 0);
    const arg = optional orelse return base ^ 64;
    return switch (arg) {
        .null => base ^ 64,
        .value => |value| base ^ value,
    };
}

fn benchSum(values: *phpz.zend.Array) i64 {
    var sum: i64 = 0;
    values.eachValue(struct {
        fn add(slot: *phpz.c.zval, total: *i64) void {
            const raw = phpz.Zval.raw;
            if (raw.is(slot, .int)) {
                total.* +%= raw.asUnchecked(slot, .int);
            } else if (raw.is(slot, .reference)) {
                @branchHint(.unlikely);
                const value = raw.asUnchecked(slot, .reference).val();
                if (raw.is(value, .int)) total.* +%= raw.asUnchecked(value, .int);
            }
        }
    }.add, .{&sum});
    return sum;
}

fn benchBuild(size: i64) !*phpz.zend.Array {
    if (size < 0 or size > 65536) {
        return phpz.exception.argumentValueError(1, "must be between 0 and 65536", .{});
    }
    if (size == 0) return .init(0);

    var list = phpz.zend.Array.ListBuilder.init(@intCast(size));
    for (0..@intCast(size)) |i| {
        list.appendAssumeCapacity(.int, @intCast(i));
    }
    return list.finish();
}

fn benchInvoke(ctx: phpz.Ctx, callback: *phpz.zend.Callable, value: i64) !void {
    try callback.callAssumeExclusive(ctx.retval.ptr(), .{phpz.Zval.raw.init(.int, value)}, null);
}

inline fn benchLookup(values: *phpz.zend.Array, key: *phpz.zend.String) ?i64 {
    const value = deref(values.symtableFindStr(key) orelse return null);
    const raw = phpz.Zval.raw;
    return if (raw.is(value, .int)) raw.asUnchecked(value, .int) else null;
}

fn benchCow(values: *phpz.zend.Array, replacement: i64) *phpz.zend.Array {
    const copy = values.dupe();
    var value = phpz.Zval.raw.init(.int, replacement);
    _ = copy.updateIndex(0, &value);
    return copy;
}

fn benchSplit(record: *phpz.zend.String) *phpz.zend.Array {
    const values = phpz.zend.Array.init(0);
    var result = phpz.Zval.raw.undef;
    phpz.Zval.raw.set(&result, .array, values);
    phpz.c.php_explode(phpz.zend.String.char(',').ptr(), record.ptr(), &result, @as(i64, std.math.maxInt(i64)));
    return values;
}

fn benchUpper(text: *phpz.zend.String) *phpz.zend.String {
    return text.toUpper();
}

fn benchLength(text: []const u8) i64 {
    return @intCast(text.len);
}

const Point = phpz.Class("BenchPoint", struct {
    pub fn read(ctx: phpz.Ctx) !i64 {
        var scratch = phpz.Zval.raw.undef;
        defer phpz.Zval.raw.release(&scratch);
        const value = try ctx.call.this().?.property("value", false, &scratch);
        return phpz.Zval.raw.asUnchecked(deref(value.ptr()), .int);
    }
}, .{});

fn deref(value: *phpz.c.zval) *phpz.c.zval {
    const raw = phpz.Zval.raw;
    if (raw.is(value, .reference)) {
        @branchHint(.unlikely);
        return raw.asUnchecked(value, .reference).val();
    }
    return value;
}
