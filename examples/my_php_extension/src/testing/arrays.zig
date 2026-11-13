const phpz = @import("phpz");
const std = @import("std");
const c = phpz.c;
const Array = phpz.zend.Array;
const String = phpz.zend.String;
const raw = phpz.Zval.raw;
const expect = std.testing.expect;

pub fn isArrayList(source: *Array) bool {
    return source.isList();
}

pub fn arrayToList(source: *Array) *Array {
    return source.toList();
}

pub fn checkArrayHashTable(references: *Array) !void {
    try checkReferenceCounts(raw.asUnchecked(references.find("empty").?, .array));
    try checkStringKeys();
    try checkPointerValues();
    try checkExtend();
    try checkReverseApply();

    // PHP supplies two references, a plain integer and an immutable empty array.
    const key = String.init("reference", false);
    defer key.release();
    const value = raw.asUnchecked(references.findStr(key).?, .reference).val();
    try expect(references.findDeref("reference") == value);
    try expect(references.findStrDeref(key) == value);
    try expect(references.findIndexDeref(0) == value);
    try expect(raw.asUnchecked(value, .int) == 7);
    try expect(references.findDeref("plain") == references.find("plain"));
    try expect(references.findDeref("absent") == null);
    try expect(references.findIndexDeref(-1) == null);
    const missing = String.init("absent", false);
    defer missing.release();
    try expect(references.findStrDeref(missing) == null);
}

fn checkReferenceCounts(immutable: *Array) !void {
    try expect(immutable.isImmutable());
    const original = immutable.refcount();
    immutable.addref();
    try expect(immutable.refcount() == original);
    immutable.delref();
    try expect(immutable.refcount() == original);
    immutable.addref();
    immutable.release();
    try expect(immutable.refcount() == original);

    const mutable = Array.empty();
    defer mutable.release();
    try expect(!mutable.isImmutable() and mutable.refcount() == 1);
    mutable.addref();
    try expect(mutable.refcount() == 2);
    mutable.delref();
    try expect(mutable.refcount() == 1);
    mutable.addref();
    mutable.release();
    try expect(mutable.refcount() == 1);
}

fn checkStringKeys() !void {
    const table = Array.empty();
    defer table.release();
    const key = String.init("binary\x00key", false);
    defer key.release();
    const same_key = String.init("binary\x00key", false);
    defer same_key.release();
    const payload = String.init("owned value", false);
    defer payload.release();
    try expect(!table.hasStr(key));
    try std.testing.expectError(error.NotFound, table.deleteStr(key));

    var value = raw.init(.str, payload.copy());
    try expect(table.addStr(key, &value) != null);
    try expect(key.refcount() == 2 and payload.refcount() == 2);
    try expect(table.findStr(same_key) == table.find("binary\x00key"));
    try expect(table.lookupStr(same_key) == table.findStr(key));
    try expect(raw.asUnchecked(table.lookupStr(key), .str) == payload);

    var rejected = raw.init(.str, payload.copy());
    try expect(table.addStr(same_key, &rejected) == null);
    try expect(payload.refcount() == 3); // Failed insertion retains caller ownership.
    raw.release(&rejected);
    value = raw.init(.int, 42);
    const updated = table.updateStr(same_key, &value);
    try expect(updated == table.findStr(same_key).?);
    try expect(raw.asUnchecked(updated, .int) == 42);
    try expect(payload.refcount() == 1); // Replacement released the old value.
    try expect(table.len() == 1 and table.hasStr(key));
    try table.deleteStr(same_key);
    try expect(key.refcount() == 1 and table.isEmpty());

    // Insertion retains the key even after the caller releases its reference.
    const temporary = String.init("temporary", false);
    _ = table.updateStr(temporary, &value);
    temporary.release();
    try expect(raw.asUnchecked(table.find("temporary").?, .int) == 42);

    const numeric = String.init("12", false);
    defer numeric.release();
    const slot = table.lookupStr(numeric);
    try expect(raw.is(slot, .null) and table.hasStr(numeric));
    try expect(table.findIndex(12) == null); // No numeric-string conversion.
    raw.set(slot, .str, payload.copy());
    try expect(table.lookupStr(numeric) == slot);
    raw.release(slot);
    raw.set(slot, .int, 11);
    try expect(payload.refcount() == 1);
    const indexed = table.lookupIndex(-4);
    try expect(raw.is(indexed, .null));
    raw.set(indexed, .int, 23);
    try expect(table.lookupIndex(-4) == indexed);
    try expect(raw.asUnchecked(indexed, .int) == 23);
    try expect(raw.asUnchecked(table.findStr(numeric).?, .int) == 11);
}

fn checkPointerValues() !void {
    const Item = struct { number: i64 };
    var a = Item{ .number = 1 };
    var b = Item{ .number = 2 };
    const table = Array.empty();
    defer table.release();
    const key = String.init("pointer", false);
    defer key.release();
    try expect(table.findStrPtr(Item, key) == null);
    try expect(table.addStrPtr(Item, key, &a) == &a);
    try expect(table.addStrPtr(Item, key, &b) == null);
    try expect(table.findStrPtr(Item, key) == &a);
    try expect(table.updateStrPtr(Item, key, &b) == &b);
    try expect(table.findPtr(Item, "pointer") == &b);
    try table.deleteStr(key);
    try expect(table.updateStrPtr(Item, key, &a) == &a);
    try expect(raw.is(table.findStr(key).?, .ptr));
    try expect(table.addPtr(Item, "slice", &a) == &a);
    try expect(table.addPtr(Item, "slice", &b) == null);
    try expect(table.updatePtr(Item, "slice", &b) == &b);
    try expect(table.findPtr(Item, "slice") == &b);
    try expect(table.addIndexPtr(Item, -3, &a) == &a);
    try expect(table.addIndexPtr(Item, -3, &b) == null);
    try expect(table.updateIndexPtr(Item, -3, &b) == &b);
    try expect(table.findIndexPtr(Item, -3) == &b);
    _ = table.updateIndexPtr(Item, 4, &a);
    try expect(table.appendPtr(Item, &b) == &b);
    try expect(table.findIndexPtr(Item, 5) == &b);
    _ = table.updateIndexPtr(Item, std.math.maxInt(isize), &a);
    try expect(table.appendPtr(Item, &b) == null);
    table.clear();
    try expect(table.isEmpty() and a.number == 1 and b.number == 2);
}

fn checkExtend() !void {
    const empty = Array.empty();
    defer empty.release();
    const flags = empty.ptr().u.flags;
    empty.extend(0);
    try expect(empty.ptr().u.flags == flags);
    empty.extend(32);
    try expect(empty.ptr().nTableSize >= 32 and empty.isEmpty());
    try expect((empty.ptr().u.flags & c.HASH_FLAG_UNINITIALIZED) == 0);
    try expect((empty.ptr().u.flags & c.HASH_FLAG_PACKED) == 0);
    var value = raw.init(.int, 17);
    _ = empty.update("key", &value);
    empty.extend(128);
    const capacity = empty.ptr().nTableSize;
    empty.extend(1);
    try expect(empty.ptr().nTableSize == capacity and empty.len() == 1);
    try expect(raw.asUnchecked(empty.find("key").?, .int) == 17);

    const list = Array.empty();
    defer list.release();
    for (0..32) |i| {
        value = raw.init(.int, @intCast(i));
        _ = list.append(&value);
    }
    try list.deleteIndex(3); // A packed table with a hole is not a list.
    try expect(!list.isList());
    list.extend(256);
    try expect(list.ptr().nTableSize >= 256 and list.len() == 31);
    try expect((list.ptr().u.flags & c.HASH_FLAG_PACKED) != 0);
    try expect(list.findIndex(3) == null);
    for (0..32) |i| {
        if (i == 3) continue;
        try expect(raw.asUnchecked(list.findIndex(@intCast(i)).?, .int) == i);
    }
    value = raw.init(.int, 99);
    _ = list.append(&value);
    try expect(raw.asUnchecked(list.findIndex(32).?, .int) == 99);
    const values = list.toList();
    defer values.release();
    try expect(values.isList() and values.len() == 32);
    try expect(raw.asUnchecked(values.findIndex(3).?, .int) == 4);
}

fn checkReverseApply() !void {
    const Callback = struct {
        threadlocal var seen: [3]i64 = undefined;
        threadlocal var count: usize = 0;
        fn keep(value: *c.zval) Array.ApplyResult {
            seen[count] = raw.asUnchecked(value, .int);
            count += 1;
            return .keep;
        }
        fn removeThenStop(value: *c.zval) Array.ApplyResult {
            _ = keep(value);
            return if (raw.asUnchecked(value, .int) == 3) .remove else .stop;
        }
        fn fail(_: *c.zval) Array.ApplyResult {
            c.zend_throw_error(null, "reverse apply failed");
            return .stop;
        }
    };
    for ([_]bool{ false, true }) |mixed| {
        const table = Array.empty();
        defer table.release();
        for (1..4) |i| {
            var value = raw.init(.int, @intCast(i));
            if (mixed and i == 3) {
                _ = table.update("last", &value);
            } else {
                _ = table.append(&value);
            }
        }
        Callback.count = 0;
        try table.reverseApply(Callback.keep);
        try std.testing.expectEqualSlices(i64, &.{ 3, 2, 1 }, &Callback.seen);
        Callback.count = 0;
        try table.reverseApply(Callback.removeThenStop);
        try expect(Callback.count == 2 and table.len() == 2);
        try std.testing.expectEqualSlices(i64, &.{ 3, 2 }, Callback.seen[0..2]);
        try expect(!table.has("last") and !table.hasIndex(2));
        const result = table.reverseApply(Callback.fail);
        const pending = phpz.exception.hasPending();
        phpz.exception.clear();
        try std.testing.expectError(error.PhpException, result);
        try expect(pending and table.len() == 2);
    }
}

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

/// Keys are slices of a larger buffer, so they are not NUL-terminated:
/// "-" and "" are followed by digits that Zend's numeric key check would read.
pub fn setSlicedKeys(ctx: phpz.Ctx) void {
    const result = phpz.Zval.Array.empty(ctx.retval.ptr());
    const buffer = "-5|7x";
    result.set(.int, buffer[0..1], 1);
    result.set(.string, buffer[1..1], "empty");
    // Numeric string keys still become integer keys.
    result.set(.bool, buffer[3..4], true);
}
