const std = @import("std");
const phpz = @import("phpz");
const Array = phpz.zend.Array;
const Zval = phpz.Zval;
const c = phpz.c;

const List = phpz.Zval.Array;

// Zval.Array.append(.mixed) transfers ownership, so append a dereferenced copy of borrowed values.
fn appendCopy(list: *List, value: *c.zval) !void {
    var copy: c.zval = undefined;
    Zval.raw.copyDeref(&copy, value);
    list.append(.mixed, &copy) catch |err| {
        Zval.raw.release(&copy);
        return err;
    };
}

fn appendEntry(out: *List, key: Array.Key, value: *c.zval) !void {
    var pair_storage = Zval.raw.undef;
    const pair = List.init(&pair_storage, 2);
    errdefer Zval.raw.release(&pair_storage);
    switch (key) {
        .int => |index| try pair.append(.int, index),
        .string => |name| try pair.append(.string, name),
    }
    try appendCopy(pair, value);
    try out.append(.mixed, &pair_storage);
}

fn expectSameValues(entries: *Array, values: *Array) !void {
    try std.testing.expectEqual(entries.len(), values.len());
    var expected = entries.fastValueIterator();
    var actual = values.fastValueIterator();
    while (expected.next()) |pair| {
        const value = actual.next() orelse return error.MissingValue;
        const recorded = Zval.raw.asUnchecked(pair, .array).findIndex(1).?;
        try std.testing.expect(c.zend_is_identical(recorded, value));
    }
}

/// PHP: MyPHPExt\Test\iterateArray(array $values): array
/// Returns [key, value] pairs after checking every iteration API agrees.
pub fn iterateArray(ctx: phpz.Ctx, values: *Array) !void {
    const out = List.empty(ctx.retval.ptr());
    var iterator = values.iterator();
    while (iterator.next()) |entry| try appendEntry(out, entry.key, entry.value);
    const entries = out.zendArray();

    var collected_storage = Zval.raw.undef;
    defer Zval.raw.release(&collected_storage);
    const collected = List.empty(&collected_storage);

    values.each(struct {
        fn callback(entry: Array.Entry, list: *List) void {
            appendEntry(list, entry.key, entry.value) catch unreachable;
        }
    }.callback, .{collected});
    try std.testing.expect(c.zend_is_identical(ctx.retval.ptr(), &collected_storage));

    inline for (.{ "eachValue", "valueIterator", "fastValueIterator", "fastIterator" }) |api| {
        var list_storage = Zval.raw.undef;
        defer Zval.raw.release(&list_storage);
        const list = List.empty(&list_storage);
        if (comptime std.mem.eql(u8, api, "eachValue")) {
            values.eachValue(struct {
                fn callback(value: *c.zval, target: *List) void {
                    appendCopy(target, value) catch unreachable;
                }
            }.callback, .{list});
        } else if (comptime std.mem.eql(u8, api, "fastIterator")) {
            var it = values.fastIterator();
            while (it.next()) |entry| try appendCopy(list, entry.value);
        } else {
            var it = @field(Array, api)(values);
            while (it.next()) |value| try appendCopy(list, value);
        }
        try expectSameValues(entries, list.zendArray());
    }

    var keys = values.keyIterator();
    var pairs = entries.fastValueIterator();
    while (keys.next()) |key| {
        const pair = Zval.raw.asUnchecked(pairs.next().?, .array);
        const recorded = pair.findIndex(0).?;
        switch (key) {
            .int => |index| try std.testing.expectEqual(index, Zval.raw.asUnchecked(recorded, .int)),
            .string => |name| try std.testing.expectEqualStrings(name, Zval.raw.asUnchecked(recorded, .string)),
        }
    }
    try std.testing.expect(pairs.next() == null);
}

/// PHP: MyPHPExt\Test\iterateWhileMutating(): array
/// Deleting the current element and growing the table between steps must
/// behave like Zend's HashPosition API: the next step resumes at the next live slot.
pub fn iterateWhileMutating(ctx: phpz.Ctx) !void {
    var table_storage = Zval.raw.undef;
    defer Zval.raw.release(&table_storage);
    const table = List.init(&table_storage, 8);
    for (0..4) |i| try table.append(.int, @intCast(i));
    const ht = table.zendArray();

    const out = List.empty(ctx.retval.ptr());
    var iterator = ht.iterator();
    while (iterator.next()) |entry| {
        const key: i64 = switch (entry.key) {
            .int => |index| index,
            .string => -1,
        };
        try out.append(.int, key);
        if (key == 0) try ht.deleteIndex(1);
        // Appending past the capacity reallocates the packed storage.
        if (key == 2) for (0..16) |i| try table.append(.int, 100 + @as(i64, @intCast(i)));
        if (key == 3) table.set(.int, "named", 7);
        if (out.len() > 32) return error.IteratorDidNotFinish;
    }
}

/// PHP: MyPHPExt\Test\buildList(int $count, int $capacity, mixed $value): array
pub fn buildList(count: u32, capacity: u32, value: *Zval) *Array {
    var builder = Array.ListBuilder.init(capacity);
    for (0..count) |i| {
        if (i < capacity) {
            if (i % 2 == 0) builder.appendAssumeCapacity(.mixed, value.ptr()) else builder.appendAssumeCapacity(.int, @intCast(i));
        } else {
            if (i % 2 == 0) builder.append(.mixed, value.ptr()) else builder.append(.int, @intCast(i));
        }
    }
    return builder.finish();
}

/// PHP: MyPHPExt\Test\lookupKey(array $values, string $key, bool $symtable): mixed
pub fn lookupKey(values: *Array, key: []const u8, symtable: bool) ?*Zval {
    const found = if (symtable) values.symtableFind(key) else values.find(key);
    return Zval.from(found orelse return null);
}

/// PHP: MyPHPExt\Test\storeKey(array $values, string $key, mixed $value): array
pub fn storeKey(ctx: phpz.Ctx, values: *Array, key: []const u8, value: *Zval) !void {
    const result = values.dupe();
    var copy: c.zval = undefined;
    Zval.raw.copy(&copy, value.ptr());
    _ = result.symtableUpdate(key, &copy);
    result.symtableDelete("drop") catch {};
    ctx.retval.set(.array, result);
}
