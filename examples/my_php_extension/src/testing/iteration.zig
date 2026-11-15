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
        .str => |name| try pair.append(.string, name.slice()),
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

    // Registered iteration also preserves keys and reference-holding values.
    // Duplicate first: registering an iterator requires mutable table storage.
    {
        const copy = values.dupe();
        defer copy.release();
        var registered = copy.mutableIterator();
        defer registered.deinit();
        var expected = entries.fastValueIterator();
        while (registered.next()) |entry| {
            const pair = Zval.raw.asUnchecked(expected.next().?, .array);
            switch (entry.key) {
                .int => |index| try std.testing.expectEqual(index, Zval.raw.asUnchecked(pair.findIndex(0).?, .int)),
                .str => |name| try std.testing.expectEqualStrings(name.slice(), Zval.raw.asUnchecked(pair.findIndex(0).?, .string)),
            }
            const value = if (Zval.raw.is(entry.value, .reference))
                Zval.raw.asUnchecked(entry.value, .reference).val()
            else
                entry.value;
            try std.testing.expect(c.zend_is_identical(pair.findIndex(1).?, value));
        }
        try std.testing.expect(expected.next() == null);
    }

    var keys = values.keyIterator();
    var pairs = entries.fastValueIterator();
    while (keys.next()) |key| {
        const pair = Zval.raw.asUnchecked(pairs.next().?, .array);
        const recorded = pair.findIndex(0).?;
        switch (key) {
            .int => |index| try std.testing.expectEqual(index, Zval.raw.asUnchecked(recorded, .int)),
            .str => |name| try std.testing.expectEqualStrings(name.slice(), Zval.raw.asUnchecked(recorded, .string)),
        }
    }
    try std.testing.expect(pairs.next() == null);
}

/// PHP: MyPHPExt\Test\iterateWhileMutating(): array
/// Registered Zend positions track deletion, growth and packed-to-mixed changes.
pub fn iterateWhileMutating(ctx: phpz.Ctx) !void {
    try checkMutableIterator();
    var table_storage = Zval.raw.undef;
    defer Zval.raw.release(&table_storage);
    const table = List.init(&table_storage, 8);
    for (0..4) |i| try table.append(.int, @intCast(i));
    const ht = table.zendArray();

    const out = List.empty(ctx.retval.ptr());
    var iterator = ht.mutableIterator();
    defer iterator.deinit();
    while (iterator.next()) |entry| {
        const key: i64 = switch (entry.key) {
            .int => |index| index,
            .str => -1,
        };
        try out.append(.int, key);
        if (key == 0) try ht.deleteIndex(1);
        // Appending past the capacity reallocates the packed storage.
        if (key == 2) for (0..16) |i| try table.append(.int, 100 + @as(i64, @intCast(i)));
        if (key == 3) table.set(.int, "named", 7);
        if (out.len() > 32) return error.IteratorDidNotFinish;
    }
}

fn checkMutableIterator() !void {
    const table = Array.init(8);
    defer table.release();
    for (0..8) |i| {
        var buffer: [16]u8 = undefined;
        const key = try std.fmt.bufPrint(&buffer, "k{d}", .{i});
        var value = Zval.raw.init(.int, @intCast(i));
        _ = table.update(key, &value);
    }
    var iterator = table.mutableIterator();
    defer iterator.deinit();
    for (0..3) |i| {
        try std.testing.expectEqual(@as(i64, @intCast(i)), Zval.raw.asUnchecked(iterator.next().?.value, .int));
    }
    // Delete both visited entries and the pending next entry, then force mixed
    // bucket compaction and growth. A plain HashPosition would lose its place.
    try table.delete("k0");
    try table.delete("k1");
    try table.delete("k3");
    var eight = Zval.raw.init(.int, 8);
    _ = table.update("k8", &eight);
    table.rehash();
    try std.testing.expectEqual(@as(i64, 4), Zval.raw.asUnchecked(iterator.current().?.value, .int));

    // More than the inline Zend iterator slots forces registry reallocation.
    // Deinitializing these must not affect the original registered position.
    {
        var nested: [24]Array.MutableIterator = undefined;
        for (&nested) |*it| it.* = table.mutableIterator();
        defer for (&nested) |*it| it.deinit();
        for (&nested) |*it| {
            try std.testing.expectEqual(@as(i64, 2), Zval.raw.asUnchecked(it.next().?.value, .int));
        }
        for (9..40) |i| {
            var buffer: [16]u8 = undefined;
            const key = try std.fmt.bufPrint(&buffer, "k{d}", .{i});
            var value = Zval.raw.init(.int, @intCast(i));
            _ = table.update(key, &value);
        }
        try std.testing.expectEqual(@as(i64, 4), Zval.raw.asUnchecked(iterator.next().?.value, .int));
    }
    for (5..40) |i| {
        const entry = iterator.next() orelse return error.MissingValue;
        try std.testing.expectEqual(@as(i64, @intCast(i)), Zval.raw.asUnchecked(entry.value, .int));
    }
    try std.testing.expect(iterator.next() == null);
    iterator.reset();
    try std.testing.expectEqual(@as(i64, 2), Zval.raw.asUnchecked(iterator.current().?.value, .int));
    iterator.advance();
    try std.testing.expectEqual(@as(i64, 4), Zval.raw.asUnchecked(iterator.current().?.value, .int));
    table.clear();
    try std.testing.expect(iterator.next() == null);
    iterator.reset();
    var after_clear = Zval.raw.init(.int, 100);
    _ = table.append(&after_clear);
    try std.testing.expectEqual(@as(i64, 100), Zval.raw.asUnchecked(iterator.next().?.value, .int));
    iterator.deinit();
    iterator.deinit();
    try std.testing.expectEqual(@as(u8, 0), table.ptr().u.v.nIteratorsCount);
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

/// PHP: MyPHPExt\Test\deleteKey(array $values, string $key): array
pub fn deleteKey(values: *Array, key: []const u8) !*Array {
    const result = values.dupe();
    errdefer result.release();
    try result.symtableDelete(key);
    return result;
}
