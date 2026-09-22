const std = @import("std");
const phpz = @import("phpz");
const Zval = phpz.Zval;
const CallFrame = phpz.CallFrame;
const Spec = CallFrame.ExpectArgKind.Spec;

/// Exercise the same spec through both the single and tuple parsing APIs.
/// The PHP value is deliberately mixed so the wrapper owns all type checks.
pub fn typedArgument(ctx: phpz.Ctx) !void {
    try ctx.call.expectNoExtraNamedArgs();
    try ctx.call.expectArgCount(2, 3);
    const mode = try ctx.call.expectArg(1, .{ .string = .{} }, {});
    const single = try ctx.call.expectArg(2, .{ .bool = .{} }, {});

    inline for (.{ .required, .nullable, .optional, .both }) |wrap| {
        const prefix = if (wrap == .required) "" else @tagName(wrap) ++ "-";
        const optional = wrap == .optional or wrap == .both;
        const nullable = wrap == .nullable or wrap == .both;
        inline for (.{ .i8, .i16, .i32, .i64, .isize, .u8, .u16, .u32, .u64, .usize }) |output| {
            if (std.mem.eql(u8, mode, prefix ++ @tagName(output))) {
                return parse(ctx, single, .{ .int = .{ .as = output, .optional = optional, .nullable = nullable } });
            }
        }
        inline for (.{ .f32, .f64 }) |output| {
            if (std.mem.eql(u8, mode, prefix ++ @tagName(output))) {
                return parse(ctx, single, .{ .float = .{ .as = output, .optional = optional, .nullable = nullable } });
            }
        }
        inline for (.{ .string, .str, .zval }) |output| {
            if (std.mem.eql(u8, mode, prefix ++ @tagName(output))) {
                return parse(ctx, single, .{ .string = .{ .as = output, .optional = optional, .nullable = nullable } });
            }
        }
        inline for (.{ .int, .float, .bool, .array, .object, .resource }) |kind| {
            if (std.mem.eql(u8, mode, prefix ++ @tagName(kind) ++ "-zval")) {
                return parse(ctx, single, @unionInit(Spec, @tagName(kind), .{ .as = .zval, .optional = optional, .nullable = nullable }));
            }
        }
    }
    return error.UnknownArgumentMode;
}

fn parse(ctx: phpz.Ctx, single: bool, comptime spec: Spec) !void {
    const optional = comptime spec.isOptional();
    try ctx.call.expectArgCount(if (optional) 2 else 3, 3);
    const result = if (single)
        try ctx.call.expectArg(3, spec, {})
    else
        (try ctx.call.expectArgs(&.{ .{ .string = .{} }, .{ .bool = .{} }, spec }, {}))[2];

    const value = if (optional) result orelse {
        ctx.ret(.string, "omitted");
        return;
    } else result;
    const options = comptime switch (spec) {
        inline else => |s| s,
    };
    if (comptime options.as == .zval) {
        try std.testing.expect(value.ptr() == ctx.call.arg(3));
        ctx.ret(.mixed, value.ptr());
    } else if (comptime options.nullable) {
        switch (value) {
            .null => ctx.ret(.null, {}),
            .value => |v| try writeValue(ctx, v),
        }
    } else try writeValue(ctx, value);
}

fn writeValue(ctx: phpz.Ctx, value: anytype) !void {
    const T = @TypeOf(value);
    if (T == *phpz.zend.String or T == []const u8) {
        const source = Zval.from(ctx.call.arg(3));
        const str = try source.as(.str);
        const count = str.refcount();
        if (T == *phpz.zend.String) {
            try std.testing.expect(value == str);
            // The return slot must own a separate reference from the argument.
            ctx.ret(.str, value.copy());
        } else {
            try std.testing.expect(value.ptr == str.slice().ptr);
            ctx.ret(.string, value);
        }
        if (!str.isInterned()) {
            try std.testing.expectEqual(count + @as(u32, if (T == *phpz.zend.String) 1 else 0), str.refcount());
        }
    } else switch (@typeInfo(T)) {
        .int => ctx.ret(.int, @intCast(value)),
        .float => ctx.ret(.float, @floatCast(value)),
        else => @compileError("unexpected typed argument test output"),
    }
}

/// Verify borrowing at parse time, before the return path obtains a reference.
pub fn checkStringArguments(ctx: phpz.Ctx) !void {
    try ctx.call.expectArgCount(1, 1);
    try ctx.call.expectNoExtraNamedArgs();
    const original = try Zval.from(ctx.call.arg(1)).as(.str);
    const count = original.refcount();
    const single = try ctx.call.expectArg(1, .{ .string = .{ .as = .str } }, {});
    const tuple = try ctx.call.expectArgs(&.{.{ .string = .{ .as = .str } }}, {});
    try std.testing.expect(original == single and original == tuple[0]);
    try std.testing.expectEqual(count, original.refcount());
    ctx.ret(.bool, true);
}

/// The fixture object has a public string `value` and static string `shared`.
pub fn checkZvalStrings(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{ .{ .string = .{} }, .{ .object = .{} } }, {});
    const str = phpz.zend.String.init(args[0], false);
    var storage = Zval.raw.init(.str, str);
    const source = Zval.from(&storage);
    defer source.release();
    const initial = str.refcount();
    try std.testing.expect(source.kind() == .string and source.is(.string) and source.is(.str));
    try std.testing.expect(Zval.raw.is(&storage, .string) and Zval.raw.is(&storage, .str));
    try std.testing.expect((try source.as(.str)) == str);
    try std.testing.expect((try source.as(.string)).ptr == str.slice().ptr);
    try std.testing.expect(source.asUnchecked(.str) == str);
    try std.testing.expect(source.asUnchecked(.string).ptr == str.slice().ptr);
    try std.testing.expectEqual(initial, str.refcount());
    try std.testing.expectEqualStrings(args[0], source.asOrDefault(.string, "fallback"));

    var number = Zval.raw.init(.int, 42);
    try std.testing.expect(!Zval.raw.is(&number, .string) and !Zval.raw.is(&number, .str));
    try std.testing.expectError(error.TypeMismatch, Zval.raw.as(&number, .string));
    try std.testing.expectError(error.TypeMismatch, Zval.raw.as(&number, .str));
    try std.testing.expectEqualStrings("fallback", Zval.from(&number).asOrDefault(.string, "fallback"));
    try std.testing.expect(Zval.from(&number).asOrDefault(.str, str) == str);
    try std.testing.expectEqualStrings("42", try Zval.raw.convert(&number, .string));
    Zval.raw.release(&number);
    number = Zval.raw.init(.int, 43);
    try std.testing.expectEqualStrings("43", (try Zval.raw.convert(&number, .str)).slice());
    Zval.raw.release(&number);

    const cast = try source.cast(.str);
    try checkRefcount(str, initial + 1);
    cast.release();
    try checkRefcount(str, initial);

    var copied = Zval.raw.init(.str, str.copy());
    try checkRefcount(str, initial + 1);
    try std.testing.expectEqual(storage.u1.type_info, copied.u1.type_info);
    Zval.raw.release(&copied);
    try checkRefcount(str, initial);

    var array_storage = Zval.raw.undef;
    const array = Zval.Array.empty(&array_storage);
    array.set(.str, "key", str.copy());
    try array.setAt(.str, 1, str.copy());
    try array.append(.str, str.copy());
    try checkRefcount(str, initial + 3);
    const first = Zval.from(array.zendArray().find("key").?);
    try std.testing.expect((try first.as(.str)) == str);
    Zval.raw.release(&array_storage);
    try checkRefcount(str, initial);

    // An occupied maximum integer key makes append fail without consuming the input.
    {
        var full_storage = Zval.raw.undef;
        const full = Zval.Array.empty(&full_storage);
        defer Zval.raw.release(&full_storage);
        try full.setAt(.null, std.math.maxInt(isize), {});
        const offered = str.copy();
        if (full.append(.str, offered)) |_| {
            return error.ExpectedAppendFailure;
        } else |err| {
            defer offered.release();
            try std.testing.expectEqual(error.AppendFailed, err);
            try checkRefcount(str, initial + 1);
            try std.testing.expectEqual(@as(u32, 1), full.len());
        }
        try checkRefcount(str, initial);
    }

    const object = args[1];
    try object.setProperty(.str, "value", str);
    try checkRefcount(str, initial + 1);
    try object.setProperty(.string, "value", "reset");
    try checkRefcount(str, initial);
    const wrapper = try Zval.Object.from(ctx.call.arg(2));
    try wrapper.set(.str, "value", str.copy());
    try checkRefcount(str, initial + 1);
    try wrapper.set(.string, "value", "reset");
    try checkRefcount(str, initial);
    try object.class().setStaticProperty(.str, "shared", str);
    try checkRefcount(str, initial + 1);
    try object.class().setStaticProperty(.string, "shared", "reset");
    try checkRefcount(str, initial);

    // Returning a separate owned reference must leave PHP with a live string.
    ctx.ret(.str, str.copy());
}

fn checkRefcount(str: *phpz.zend.String, expected: u32) !void {
    if (!str.isInterned()) try std.testing.expectEqual(expected, str.refcount());
}

/// Check ownership after a rejected property write, including exception traces.
pub fn checkStringWriteFailure(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{ .{ .object = .{} }, .{ .string = .{} }, .{ .string = .{} } }, {});
    const str = phpz.zend.String.init("owned nonnumeric string for a rejected write", false);
    defer str.release();
    try std.testing.expect(!str.isInterned());
    try std.testing.expectEqual(@as(u32, 1), str.refcount());

    const result: anyerror!void = if (std.mem.eql(u8, args[1], "object"))
        args[0].setProperty(.str, "value", str)
    else if (std.mem.eql(u8, args[1], "zval"))
        // This API consumes the offered reference even when the write fails.
        (try Zval.Object.from(ctx.call.arg(1))).set(.str, "value", str.copy())
    else if (std.mem.eql(u8, args[1], "static"))
        args[0].class().setStaticProperty(.str, "shared", str)
    else
        return error.UnknownPropertyAPI;

    const pending = phpz.errors.exception();
    const expected_exception = if (pending) |exception|
        std.mem.eql(u8, args[2], exception.class().name())
    else
        false;
    // A __set() exception trace may temporarily retain the string argument.
    // Clear it before checking ownership and before assertions can throw.
    phpz.errors.clearException();
    try std.testing.expectError(error.PhpException, result);
    try std.testing.expect(expected_exception);
    try std.testing.expectEqual(@as(u32, 1), str.refcount());
}
