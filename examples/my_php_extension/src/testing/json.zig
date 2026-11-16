const std = @import("std");
const phpz = @import("phpz");
const Zval = phpz.Zval;

pub fn encodeJson(value: *Zval, partial: ?bool) !*phpz.zend.String {
    return phpz.json.encode(value, .{ .flags = .{ .partial_output_on_error = partial orelse false } });
}

pub fn decodeJson(ctx: phpz.Ctx, input: []const u8, associative: ?bool) !void {
    try phpz.json.decode(ctx.retval, input, .{ .flags = .{ .object_as_array = associative orelse false } });
}

pub fn exportValue(value: *Zval) !*phpz.zend.String {
    return phpz.variable.inspect(value);
}

pub fn dumpValue(value: *Zval) !void {
    try phpz.variable.dump(value);
}

fn encodeString(input: []const u8, options: phpz.json.EncodeOptions, expected: []const u8) !void {
    var value = Zval.raw.init(.string, input);
    defer Zval.raw.release(&value);
    const result = try phpz.json.encode(.from(&value), options);
    defer result.release();
    try std.testing.expectEqualStrings(expected, result.slice());
}

pub fn checkJsonOptions() !void {
    try encodeString("<>&'\"", .{ .flags = .{ .hex_tag = true, .hex_amp = true, .hex_apos = true, .hex_quot = true } }, "\"\\u003C\\u003E\\u0026\\u0027\\u0022\"");
    try encodeString("/中文", .{ .flags = .{ .unescaped_slashes = true, .unescaped_unicode = true } }, "\"/中文\"");
    try encodeString("\u{2028}", .{ .flags = .{ .unescaped_unicode = true, .unescaped_line_terminators = true } }, "\"\u{2028}\"");
    try encodeString("42", .{ .flags = .{ .numeric_check = true } }, "42");
    try encodeString("a\xffb", .{ .flags = .{ .invalid_utf8_ignore = true } }, "\"ab\"");
    try encodeString("a\xffb", .{ .flags = .{ .invalid_utf8_substitute = true } }, "\"a\\ufffdb\"");

    try encodeString("a\xffb", .{ .flags = .{ .partial_output_on_error = true } }, "null");
    try encodeString("a\xffb", .{ .flags = .{ .invalid_utf8_ignore = true, .invalid_utf8_substitute = true } }, "\"ab\"");
    var scalar = Zval.raw.init(.float, 1.0);
    const floating = try phpz.json.encode(.from(&scalar), .{ .flags = .{ .preserve_zero_fraction = true } });
    defer floating.release();
    try std.testing.expectEqualStrings("1.0", floating.slice());
    try std.testing.expectError(error.InvalidDepth, phpz.json.encode(.from(&scalar), .{ .depth = 0 }));
    try std.testing.expectError(error.InvalidDepth, phpz.json.encode(.from(&scalar), .{ .depth = std.math.maxInt(usize) }));

    var array_value = Zval.raw.undef;
    const array = Zval.Array.empty(&array_value);
    defer Zval.raw.release(&array_value);
    array.set(.int, "x", 1);
    const pretty = try phpz.json.encode(.from(&array_value), .{ .flags = .{ .pretty_print = true } });
    defer pretty.release();
    try std.testing.expectEqualStrings("{\n    \"x\": 1\n}", pretty.slice());
    var empty_value = Zval.raw.undef;
    _ = Zval.Array.empty(&empty_value);
    defer Zval.raw.release(&empty_value);
    const object = try phpz.json.encode(.from(&empty_value), .{ .flags = .{ .force_object = true } });
    defer object.release();
    try std.testing.expectEqualStrings("{}", object.slice());

    var decoded = Zval.raw.undef;
    defer Zval.raw.release(&decoded);
    try phpz.json.decode(.from(&decoded), "9223372036854775808123", .{ .flags = .{ .bigint_as_string = true } });
    try std.testing.expectEqualStrings("9223372036854775808123", try Zval.from(&decoded).as(.string));
    Zval.raw.release(&decoded);
    decoded = Zval.raw.undef;
    try phpz.json.decode(.from(&decoded), "\"a\xffb\"", .{ .flags = .{ .invalid_utf8_substitute = true } });
    try std.testing.expectEqualStrings("a\u{fffd}b", try Zval.from(&decoded).as(.string));
    Zval.raw.release(&decoded);
    decoded = Zval.raw.undef;
    try phpz.json.decode(.from(&decoded), "\"a\xffb\"", .{ .flags = .{ .invalid_utf8_ignore = true } });
    try std.testing.expectEqualStrings("ab", try Zval.from(&decoded).as(.string));
    Zval.raw.release(&decoded);
    decoded = Zval.raw.undef;

    try std.testing.expectError(error.InvalidDepth, phpz.json.decode(.from(&decoded), "null", .{ .depth = 0 }));
    try std.testing.expectError(error.InvalidDepth, phpz.json.decode(.from(&decoded), "null", .{ .depth = std.math.maxInt(usize) }));
    try std.testing.expectError(error.JsonDecodeFailed, phpz.json.decode(.from(&decoded), "[[1]]", .{ .depth = 2 }));
    try phpz.json.decode(.from(&decoded), "[[1]]", .{ .depth = 3 });
    try std.testing.expectError(error.JsonEncodeFailed, phpz.json.encode(.from(&decoded), .{ .depth = 1 }));
    const nested = try phpz.json.encode(.from(&decoded), .{ .depth = 2 });
    defer nested.release();
    try std.testing.expectEqualStrings("[[1]]", nested.slice());
}
