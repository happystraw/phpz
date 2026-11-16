const std = @import("std");
const c = @import("c.zig").c;
const exception = @import("exception.zig");
const Zval = @import("zval.zig").Zval;
const String = @import("zend/string.zig").String;

pub const EncodeFlags = packed struct(c_int) {
    hex_tag: bool = false,
    hex_amp: bool = false,
    hex_apos: bool = false,
    hex_quot: bool = false,
    force_object: bool = false,
    numeric_check: bool = false,
    unescaped_slashes: bool = false,
    pretty_print: bool = false,
    unescaped_unicode: bool = false,
    partial_output_on_error: bool = false,
    preserve_zero_fraction: bool = false,
    unescaped_line_terminators: bool = false,
    _reserved12: u8 = 0,
    invalid_utf8_ignore: bool = false,
    invalid_utf8_substitute: bool = false,
    _reserved22: u10 = 0,
};

pub const DecodeFlags = packed struct(c.zend_long) {
    object_as_array: bool = false,
    bigint_as_string: bool = false,
    _reserved2: u18 = 0,
    invalid_utf8_ignore: bool = false,
    invalid_utf8_substitute: bool = false,
    _reserved22: u42 = 0,
};

pub const EncodeOptions = struct {
    depth: usize = 512,
    flags: EncodeFlags = .{},
};

pub const DecodeOptions = struct {
    depth: usize = 512,
    flags: DecodeFlags = .{},
};

pub const EncodeError = exception.Error || error{ InvalidDepth, JsonEncodeFailed };
pub const DecodeError = exception.Error || error{ InvalidDepth, JsonDecodeFailed };

/// Encode a borrowed value; caller owns the string and must release() it.
/// Requires an active request. PHP hook exceptions stay pending; bailouts propagate.
/// JSON errors return JsonEncodeFailed unless partial output is enabled.
/// Updates PHP's json_last_error() state; does not synthesize JsonException.
pub fn encode(value: *Zval, options: EncodeOptions) EncodeError!*String {
    const depth = try checkedDepth(options.depth);
    std.debug.assert(options.flags._reserved12 == 0 and options.flags._reserved22 == 0);
    var buffer: c.smart_str = std.mem.zeroes(c.smart_str);
    errdefer c.smart_str_free(&buffer);
    const flags = @backingInt(options.flags);
    const result = c.php_json_encode_ex(&buffer, value.ptr(), flags, depth);
    try exception.check();
    // Some failures (e.g. INF/NAN) only set JSON_G(error_code).
    if (!options.flags.partial_output_on_error and
        (result != c.SUCCESS or c.phpz_json_last_error() != c.PHP_JSON_ERROR_NONE))
        return error.JsonEncodeFailed;
    c.smart_str_0(&buffer);
    return if (buffer.s) |str| String.from(str) else String.init("", false);
}

/// Decode into an undef/null destination; caller must release it even on error.
/// Requires an active request; bailouts propagate. Invalid JSON is JsonDecodeFailed.
/// Successful decoding does not reset PHP's json_last_error() state.
pub fn decode(destination: *Zval, input: []const u8, options: DecodeOptions) DecodeError!void {
    std.debug.assert(destination.is(.undef) or destination.is(.null));
    std.debug.assert(options.flags._reserved2 == 0 and options.flags._reserved22 == 0);
    const depth = try checkedDepth(options.depth);
    const flags = @backingInt(options.flags);
    const result = c.php_json_decode_ex(destination.ptr(), input.ptr, input.len, flags, depth);
    try exception.check();
    if (result != c.SUCCESS) return error.JsonDecodeFailed;
}

fn checkedDepth(depth: usize) error{InvalidDepth}!c_int {
    if (depth == 0) return error.InvalidDepth;
    return std.math.cast(c_int, depth) orelse error.InvalidDepth;
}

comptime {
    const encode_flags = .{
        .{ "hex_tag", c.PHP_JSON_HEX_TAG },
        .{ "hex_amp", c.PHP_JSON_HEX_AMP },
        .{ "hex_apos", c.PHP_JSON_HEX_APOS },
        .{ "hex_quot", c.PHP_JSON_HEX_QUOT },
        .{ "force_object", c.PHP_JSON_FORCE_OBJECT },
        .{ "numeric_check", c.PHP_JSON_NUMERIC_CHECK },
        .{ "unescaped_slashes", c.PHP_JSON_UNESCAPED_SLASHES },
        .{ "pretty_print", c.PHP_JSON_PRETTY_PRINT },
        .{ "unescaped_unicode", c.PHP_JSON_UNESCAPED_UNICODE },
        .{ "partial_output_on_error", c.PHP_JSON_PARTIAL_OUTPUT_ON_ERROR },
        .{ "preserve_zero_fraction", c.PHP_JSON_PRESERVE_ZERO_FRACTION },
        .{ "unescaped_line_terminators", c.PHP_JSON_UNESCAPED_LINE_TERMINATORS },
        .{ "invalid_utf8_ignore", c.PHP_JSON_INVALID_UTF8_IGNORE },
        .{ "invalid_utf8_substitute", c.PHP_JSON_INVALID_UTF8_SUBSTITUTE },
    };
    for (encode_flags) |entry| {
        var flags: EncodeFlags = .{};
        @field(flags, entry[0]) = true;
        if (@backingInt(flags) != entry[1])
            @compileError("PHP JSON encode flag mismatch: " ++ entry[0]);
    }
    const decode_flags = .{
        .{ "object_as_array", c.PHP_JSON_OBJECT_AS_ARRAY },
        .{ "bigint_as_string", c.PHP_JSON_BIGINT_AS_STRING },
        .{ "invalid_utf8_ignore", c.PHP_JSON_INVALID_UTF8_IGNORE },
        .{ "invalid_utf8_substitute", c.PHP_JSON_INVALID_UTF8_SUBSTITUTE },
    };
    for (decode_flags) |entry| {
        var flags: DecodeFlags = .{};
        @field(flags, entry[0]) = true;
        if (@backingInt(flags) != entry[1])
            @compileError("PHP JSON decode flag mismatch: " ++ entry[0]);
    }
}
