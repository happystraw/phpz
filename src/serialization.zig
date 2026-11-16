const std = @import("std");

const c = @import("c.zig").c;
const exception = @import("exception.zig");
const String = @import("zend/string.zig").String;
const Array = @import("zend/array.zig").Array;
const Zval = @import("zval.zig").Zval;

pub const UnserializeOptions = struct {
    allowed_classes: union(enum) {
        all,
        none,
        only: []const []const u8,
    } = .all,
    /// null preserves the context limit (INI default or inherited); 0 disables it.
    max_depth: ?usize = null,

    /// Export PHP options, copying class names and omitting default-valued keys.
    /// Caller owns the array; call release() when done.
    pub fn toArray(self: UnserializeOptions) OptionsError!*Array {
        const depth = if (self.max_depth) |value|
            std.math.cast(c.zend_long, value) orelse return error.InvalidMaxDepth
        else
            null;

        var storage = Zval.raw.undef;
        const array = Zval.Array.init(&storage, 2);
        errdefer Zval.raw.release(&storage);
        switch (self.allowed_classes) {
            .all => {},
            .none => array.set(.bool, "allowed_classes", false),
            .only => |names| {
                var classes_storage = Zval.raw.undef;
                const classes = Zval.Array.empty(&classes_storage);
                errdefer Zval.raw.release(&classes_storage);
                for (names) |name| try classes.append(.string, name);
                array.set(.array, "allowed_classes", classes.zendArray());
            },
        }
        if (depth) |value| array.set(.int, "max_depth", @intCast(value));
        return array.zendArray();
    }
};

pub const OptionsError = Zval.Array.AppendError || error{InvalidMaxDepth};
pub const UnserializeError = exception.Error || OptionsError;

/// Serialize a borrowed value using PHP's native format and object hooks.
/// Caller owns the returned string; call release() when done.
pub fn serialize(value: *Zval) exception.Error!*String {
    var buffer: c.smart_str = std.mem.zeroes(c.smart_str);
    errdefer c.smart_str_free(&buffer);
    {
        var data = c.php_var_serialize_init();
        defer c.php_var_serialize_destroy(data);
        c.php_var_serialize(&buffer, value.ptr(), &data);
    }
    try exception.check();
    c.smart_str_0(&buffer);
    return if (buffer.s) |str| String.from(str) else String.init("", false);
}

/// Decode into an undef/null destination; caller must release it even on error.
/// Class names are borrowed. Depth exceeding PHP's integer range is InvalidMaxDepth.
/// Invalid input returns false and may warn; false is also a valid decoded value.
/// Never deserialize untrusted input, even with class restrictions.
pub fn unserialize(destination: *Zval, input: []const u8, options: UnserializeOptions) UnserializeError!void {
    std.debug.assert(destination.is(.undef) or destination.is(.null));
    const array = try options.toArray();
    defer array.release();
    c.php_unserialize_with_options(destination.ptr(), input.ptr, input.len, array.ptr(), "unserialize");
    try exception.check();
}
