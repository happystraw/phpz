const std = @import("std");
const phpz = @import("phpz");
const c = phpz.c;
const expect = std.testing.expect;

// Check the Zig error as well as EG(exception); PHP alone would also throw if
// a broken wrapper returned success while leaving the exception pending.
fn expectPhpException(result: anytype) !void {
    const pending = phpz.errors.hasException();
    phpz.errors.clearException();
    try std.testing.expectError(error.PhpException, result);
    try expect(pending);
}

fn removeWithException(_: *c.zval) phpz.zend.Array.ApplyResult {
    if (!phpz.errors.hasException()) c.zend_throw_error(null, "apply failed");
    return .remove;
}

fn stopWithException(_: *c.zval, calls: *usize) phpz.zend.Array.ApplyResult {
    calls.* += 1;
    if (calls.* == 1) return .remove;
    c.zend_throw_error(null, "apply failed");
    return .stop;
}

fn sortWithException(a: *c.Bucket, b: *c.Bucket) phpz.zend.Array.SortOrder {
    if (!phpz.errors.hasException()) c.zend_throw_error(null, "sort failed");
    const left = phpz.Zval.raw.asUnchecked(&a.val, .int);
    const right = phpz.Zval.raw.asUnchecked(&b.val, .int);
    return if (left < right) .less else if (left > right) .greater else .equal;
}

pub fn checkArrayCallbacks(ctx: phpz.Ctx) !void {
    _ = try ctx.call.expectArgs(&.{}, {});
    const source = phpz.zend.Array.empty();
    defer source.release();
    for ([_]i64{ 3, 2, 1 }) |number| {
        var value = phpz.Zval.raw.init(.int, number);
        _ = source.append(&value);
    }

    const removed = source.dupe();
    defer removed.release();
    try expectPhpException(removed.apply(removeWithException));
    try expect(removed.len() == 0); // The wrapper must not override .remove with .stop.

    const stopped = source.dupe();
    defer stopped.release();
    var calls: usize = 0;
    try expectPhpException(stopped.applyWithArg(usize, stopWithException, &calls));
    try expect(calls == 2 and stopped.len() == 2); // Removal is not rolled back.

    try expectPhpException(source.sort(sortWithException, true));
    var iterator = source.valueIterator();
    var expected: i64 = 1;
    while (iterator.next()) |value| : (expected += 1) {
        try expect(phpz.Zval.raw.asUnchecked(value, .int) == expected);
    }
    try expect(expected == 4);
}

fn noProperties(_: ?*c.zend_object) callconv(.c) ?*c.HashTable {
    return null;
}

fn throwingProperties(obj: ?*c.zend_object) callconv(.c) ?*c.HashTable {
    c.zend_throw_error(null, "properties failed");
    return c.zend_std_get_properties(obj);
}

fn throwingNoProperties(obj: ?*c.zend_object) callconv(.c) ?*c.HashTable {
    _ = throwingProperties(obj);
    return null;
}

pub fn checkObjectPropertyHandlers(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{.{ .object = .{ .optional = true, .nullable = true } }}, {});
    if (args[0]) |arg| {
        if (arg.asOptional()) |lazy| {
            try expectPhpException(lazy.stdProperties());
            try expectPhpException(lazy.properties());
            return;
        }
    }
    const obj = phpz.zend.Object.std();
    defer obj.release();
    const table = (try obj.stdProperties()).?;
    const refs = table.refcount();
    var handlers = obj.ptr().handlers.*;
    obj.ptr().handlers = &handlers;

    try expect((try obj.properties()).? == table);
    handlers.get_properties = noProperties;
    try expect(try obj.properties() == null);
    handlers.get_properties = throwingProperties;
    try expectPhpException(obj.properties());
    handlers.get_properties = throwingNoProperties;
    try expectPhpException(obj.properties());
    try expect(table.refcount() == refs);
}

const CreationStage = enum { exception, init, constructor, call, cleanup };
// Bailout can leave an object alive until request shutdown, so its handlers
// must not point into a skipped or returned stack frame.
threadlocal var creation_handlers: c.zend_object_handlers = undefined;
threadlocal var creation_stage: CreationStage = .exception;
threadlocal var freed: usize = 0;
threadlocal var destructed: usize = 0;

fn createObject(ce: ?*c.zend_class_entry) callconv(.c) ?*c.zend_object {
    if (creation_stage == .init) phpz.zend.bailout.raise();
    const obj = phpz.zend.Object.initStd(.from(ce.?)).ptr();
    obj.handlers = &creation_handlers;
    if (creation_stage == .exception) c.zend_throw_error(null, "factory failed");
    return obj;
}

fn getConstructor(obj: ?*c.zend_object) callconv(.c) ?*c.zend_function {
    if (creation_stage == .constructor) phpz.zend.bailout.raise();
    if (creation_stage == .cleanup) {
        c.zend_throw_error(null, "constructor lookup failed");
        return null;
    }
    return c.zend_std_get_constructor(obj);
}

fn destroyObject(obj: ?*c.zend_object) callconv(.c) void {
    destructed += 1;
    if (creation_stage == .cleanup) phpz.zend.bailout.raise();
    c.zend_objects_destroy_object(obj);
}

fn freeObject(obj: ?*c.zend_object) callconv(.c) void {
    freed += 1;
    c.zend_object_std_dtor(obj);
}

pub fn checkObjectCreation(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{.{ .string = .{} }}, {});
    creation_stage = std.meta.stringToEnum(CreationStage, args[0]) orelse return error.InvalidStage;
    // Each PHPT defines this dedicated user class; no other class is modified.
    const entry = (try phpz.ClassEntry.lookup("NativeBoundaryTarget", false)) orelse return error.ClassNotFound;
    creation_handlers = c.std_object_handlers;
    creation_handlers.get_constructor = getConstructor;
    creation_handlers.dtor_obj = destroyObject;
    creation_handlers.free_obj = freeObject;
    c.phpz_class_entry_set_create_object(entry.ptr(), createObject);
    defer c.phpz_class_entry_set_create_object(entry.ptr(), null);
    freed = 0;
    destructed = 0;

    if (creation_stage == .exception) {
        try expectPhpException(phpz.zend.Object.init(entry));
        try expect(freed == 1 and destructed == 0);
        return;
    }

    defer std.debug.print("outer cleanup\n", .{});
    const obj = phpz.zend.Object.tryNew(entry, .{}, null) catch |err| {
        std.debug.print("caught {s}\n", .{@errorName(err)});
        return err; // Continue bailout propagation; never resume PHP execution.
    };
    obj.release();
    return error.ExpectedBailout;
}
