const std = @import("std");
const c = @import("c.zig").c;
const exception = @import("exception.zig");
const Zval = @import("zval.zig").Zval;
const String = @import("zend/string.zig").String;

pub const ExportError = exception.Error || error{ExportFailed};

/// Export a borrowed value as PHP code; caller owns the string and must release() it.
/// Requires an active request; exceptions stay pending and bailouts propagate.
/// Like var_export(), circular references warn and become NULL.
pub fn inspect(value: *Zval) ExportError!*String {
    var buffer: c.smart_str = std.mem.zeroes(c.smart_str);
    errdefer c.smart_str_free(&buffer);
    const result = c.php_var_export_ex(value.ptr(), 1, &buffer);
    try exception.check();
    if (comptime @TypeOf(result) != void) {
        if (result != c.SUCCESS) return error.ExportFailed;
    }
    c.smart_str_0(&buffer);
    return if (buffer.s) |str| String.from(str) else String.init("", false);
}

/// Dump a borrowed value to PHP output, including __debugInfo() hooks.
/// Requires an active request; exceptions stay pending and bailouts propagate.
pub fn dump(value: *Zval) exception.Error!void {
    c.php_var_dump(value.ptr(), 1);
    try exception.check();
}
