const std = @import("std");
const phpz = @import("phpz");
const c = phpz.c;
const Object = phpz.zend.Object;
const Array = phpz.zend.Array;
const String = phpz.zend.String;
const raw = phpz.Zval.raw;
const expect = std.testing.expect;

pub fn objectView(ctx: phpz.Ctx, object: *Object, purpose: []const u8) !void {
    const kind = std.meta.stringToEnum(Object.PropertyPurpose, purpose) orelse return error.UnknownPurpose;
    const view = try object.propertiesFor(kind);
    defer Object.releaseProperties(view);
    if (view) |table| ctx.ret(.array, table.dupe()) else ctx.ret(.null, {});
}

pub fn readObjectNative(ctx: phpz.Ctx, object: *Object, name: *String, api: []const u8) !void {
    var scratch = raw.undef;
    defer raw.release(&scratch);
    const result = if (std.mem.eql(u8, api, "str"))
        (try object.propertyStr(name, false, &scratch)).ptr()
    else if (std.mem.eql(u8, api, "handler"))
        try object.readProperty(name.slice(), .read, &scratch)
    else if (std.mem.eql(u8, api, "handler-str"))
        try object.readPropertyStr(name, .read, &scratch)
    else if (std.mem.eql(u8, api, "isset"))
        try object.readPropertyStr(name, .isset, &scratch)
    else
        return error.UnknownApi;
    ctx.ret(.mixed, result);
}

pub fn writeObjectNative(object: *Object, name: *String, input: *phpz.Zval, api: []const u8) !void {
    const value = if (input.is(.reference)) input.asUnchecked(.reference).val() else input.ptr();
    if (std.mem.eql(u8, api, "str")) {
        try object.setPropertyStr(.mixed, name, value);
    } else if (std.mem.eql(u8, api, "string")) {
        try object.setPropertyStr(.string, name, try raw.as(value, .string));
    } else if (std.mem.eql(u8, api, "zend-string")) {
        try object.setPropertyStr(.str, name, try raw.as(value, .str));
    } else if (std.mem.eql(u8, api, "handler")) {
        _ = try object.writeProperty(name.slice(), value);
    } else if (std.mem.eql(u8, api, "handler-str")) {
        _ = try object.writePropertyStr(name, value);
    } else if (std.mem.eql(u8, api, "standard")) {
        _ = try object.writeStdProperty(name.slice(), value);
    } else return error.UnknownApi;
}

pub fn objectDimension(ctx: phpz.Ctx, object: *Object, action: []const u8, offset: *phpz.Zval, input: *phpz.Zval) !void {
    const value = if (input.is(.reference)) input.asUnchecked(.reference).val() else input.ptr();
    if (std.mem.eql(u8, action, "read")) {
        var scratch = raw.undef;
        defer raw.release(&scratch);
        ctx.ret(.mixed, try object.readDimension(offset.ptr(), .read, &scratch));
    } else if (std.mem.eql(u8, action, "write")) {
        try object.writeDimension(offset.ptr(), value);
    } else if (std.mem.eql(u8, action, "append")) {
        try object.writeDimension(null, value);
    } else if (std.mem.eql(u8, action, "isset")) {
        ctx.ret(.bool, try object.hasDimension(offset.ptr(), .isset));
    } else if (std.mem.eql(u8, action, "not-empty")) {
        ctx.ret(.bool, try object.hasDimension(offset.ptr(), .not_empty));
    } else if (std.mem.eql(u8, action, "unset")) {
        try object.unsetDimension(offset.ptr());
    } else return error.UnknownAction;
}

// A custom handler may return a view while leaving an exception pending.
pub fn checkObjectViews(empty: *Array) !void {
    const Handler = struct {
        threadlocal var view: ?*Array = null;
        threadlocal var throws = false;
        fn properties(_: [*c]c.zend_object, _: c.zend_prop_purpose) callconv(.c) [*c]c.zend_array {
            if (throws) c.zend_throw_error(null, "view failed");
            if (view) |table| {
                if (!table.isImmutable()) table.addref();
                return table.ptr();
            }
            return null;
        }
        fn read(_: [*c]c.zend_object, _: [*c]c.zend_string, _: c_int, _: [*c]?*anyopaque, rv: [*c]c.zval) callconv(.c) [*c]c.zval {
            raw.set(rv, .string, "custom handler");
            return rv;
        }
        fn write(_: [*c]c.zend_object, _: [*c]c.zend_string, value: [*c]c.zval, _: [*c]?*anyopaque) callconv(.c) [*c]c.zval {
            return value;
        }
    };
    const object = Object.std();
    defer object.release();
    var handlers = object.ptr().handlers.*;
    handlers.get_properties_for = Handler.properties;
    handlers.read_property = Handler.read;
    handlers.write_property = Handler.write;
    object.ptr().handlers = &handlers;
    Handler.view = null;
    Handler.throws = false;
    defer Handler.view = null;
    try expect(try object.propertiesFor(.json) == null);
    Object.releaseProperties(null);
    try expect(empty.isImmutable());
    const count = empty.ptr().gc.refcount;
    Handler.view = empty;
    Object.releaseProperties(try object.propertiesFor(.debug));
    try expect(empty.ptr().gc.refcount == count);

    const table = Array.empty();
    defer table.release();
    Handler.view = table;
    const view = try object.propertiesFor(.array_cast);
    try expect(view == table and table.refcount() == 2);
    Object.releaseProperties(view);
    try expect(table.refcount() == 1);
    Handler.throws = true;
    const result = object.propertiesFor(.serialize);
    const pending = phpz.exception.hasPending();
    phpz.exception.clear();
    try std.testing.expectError(error.PhpException, result);
    try expect(pending and table.refcount() == 1);

    var scratch = raw.undef;
    defer raw.release(&scratch);
    const value = try object.readProperty("value", .read, &scratch);
    try expect(value == &scratch);
    try std.testing.expectEqualStrings("custom handler", raw.asUnchecked(value, .string));
    try expect(try object.writeProperty("value", &scratch) == &scratch);
    try expect(raw.asUnchecked(&scratch, .str).refcount() == 1);

    const ordinary = Object.std();
    defer ordinary.release();
    const name = String.init("number", false);
    defer name.release();
    try ordinary.setPropertyStr(.int, name, 42);
    var ordinary_scratch = raw.undef;
    defer raw.release(&ordinary_scratch);
    try expect((try ordinary.propertyStr(name, false, &ordinary_scratch)).asUnchecked(.int) == 42);
}

/// Discarded and missing-method results of callIfExists/tryCallIfExists.
/// `target.make()` returns an object whose destructor reports its release.
pub fn checkCallIfExists(target: *Object) !void {
    const no_params: []c.zval = &.{};
    try target.callIfExists("make", null, no_params);
    try target.tryCallIfExists("make", null, no_params);
    try std.testing.expectError(error.MethodCallFailed, target.callIfExists("missing", null, no_params));
    try std.testing.expectError(error.MethodCallFailed, target.tryCallIfExists("missing", null, no_params));

    var result = raw.undef;
    try target.callIfExists("make", &result, no_params);
    try expect(raw.is(&result, .object));
    raw.release(&result);

    var missing = raw.init(.int, 1);
    try std.testing.expectError(error.MethodCallFailed, target.callIfExists("missing", &missing, no_params));
    try expect(raw.is(&missing, .undef));
}
