const std = @import("std");
const phpz = @import("phpz");
const c = phpz.c;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

/// `input` is an immutable array supplied by PHP (for example `[]`).
pub fn checkWriteOwnership(input: *phpz.zend.Array) !void {
    try expect(input.isImmutable());
    try checkImmutable(input);
    try checkImmutable(phpz.zend.Array.from(@constCast(&c.zend_empty_array)));
    try checkMutable();
    try checkFailedAppend();
}

/// Immutable inputs must be stored without the refcounted flag; otherwise
/// destroying the container would delref read-only storage.
fn checkImmutable(immutable: *phpz.zend.Array) !void {
    var array_value: c.zval = undefined;
    const array = phpz.Zval.Array.empty(&array_value);
    defer phpz.Zval.raw.release(&array_value);
    var object_value: c.zval = undefined;
    const object = phpz.Zval.Object.std(&object_value);
    defer phpz.Zval.raw.release(&object_value);

    array.set(.array, "immutable", immutable);
    try array.setAt(.array, 0, immutable);
    try array.append(.array, immutable);
    try object.set(.array, "immutable", immutable);

    var entries = array.zendArray().valueIterator();
    var count: usize = 0;
    while (entries.next()) |value| : (count += 1) {
        try expectEqual(@as(u32, c.IS_ARRAY), value.u1.type_info);
    }
    try expectEqual(@as(usize, 3), count);

    var scratch: c.zval = undefined;
    const property = try object.zendObject().readProperty("immutable", .read, &scratch);
    try expectEqual(@as(u32, c.IS_ARRAY), property.u1.type_info);
}

/// Mutable inputs still transfer one reference to each destination.
fn checkMutable() !void {
    var array_value: c.zval = undefined;
    const array = phpz.Zval.Array.empty(&array_value);
    defer phpz.Zval.raw.release(&array_value);
    var object_value: c.zval = undefined;
    const object = phpz.Zval.Object.std(&object_value);
    defer phpz.Zval.raw.release(&object_value);

    const mutable = phpz.zend.Array.empty();
    defer mutable.release();
    mutable.addref();
    array.set(.array, "mutable", mutable);
    mutable.addref();
    try array.setAt(.array, 2, mutable);
    mutable.addref();
    try array.append(.array, mutable);
    mutable.addref();
    try object.set(.array, "mutable", mutable);
    try expectEqual(@as(u32, 5), mutable.refcount());

    array.zendArray().clear();
    try object.zendObject().unsetProperty("mutable");
    try expectEqual(@as(u32, 1), mutable.refcount());
}

/// Exhaust the next index: copied strings are freed, transferred arrays stay owned.
fn checkFailedAppend() !void {
    var array_value: c.zval = undefined;
    const array = phpz.Zval.Array.empty(&array_value);
    defer phpz.Zval.raw.release(&array_value);
    try array.setAt(.int, std.math.maxInt(isize), 0);

    const payload: [4096]u8 = @splat('x');
    const before = c.zend_memory_usage(false);
    for (0..16) |_| {
        try expectError(error.AppendFailed, array.append(.string, &payload));
    }
    try expectEqual(before, c.zend_memory_usage(false));

    const mutable = phpz.zend.Array.empty();
    defer mutable.release();
    try expectError(error.AppendFailed, array.append(.array, mutable));
    try expectEqual(@as(u32, 1), mutable.refcount());
}
