//! PHP E_* diagnostics and the most recently recorded error.
const phpz = @import("root.zig");
const c = phpz.c;
const globals = phpz.globals;
const zend = @import("zend.zig");

/// PHP error levels
///
/// These levels correspond to PHP's E_* constants
pub const Level = enum(c_int) {
    /// E_ERROR: Fatal runtime error (script terminates)
    err = c.E_ERROR,
    /// E_WARNING: Runtime warning (non-fatal)
    warning = c.E_WARNING,
    /// E_PARSE: Compile-time parse error
    parse = c.E_PARSE,
    /// E_NOTICE: Runtime notice
    notice = c.E_NOTICE,
    /// E_CORE_ERROR: Fatal error during PHP startup
    core_error = c.E_CORE_ERROR,
    /// E_CORE_WARNING: Warning during PHP startup
    core_warning = c.E_CORE_WARNING,
    /// E_COMPILE_ERROR: Fatal compile-time error
    compile_error = c.E_COMPILE_ERROR,
    /// E_COMPILE_WARNING: Compile-time warning
    compile_warning = c.E_COMPILE_WARNING,
    /// E_USER_ERROR: User-triggered error
    user_error = c.E_USER_ERROR,
    /// E_USER_WARNING: User-triggered warning
    user_warning = c.E_USER_WARNING,
    /// E_USER_NOTICE: User-triggered notice
    user_notice = c.E_USER_NOTICE,
    /// E_STRICT: Code standardization suggestion
    strict = c.E_STRICT,
    /// E_RECOVERABLE_ERROR: Catchable fatal error
    recoverable_error = c.E_RECOVERABLE_ERROR,
    /// E_DEPRECATED: Runtime deprecation notice
    deprecated = c.E_DEPRECATED,
    /// E_USER_DEPRECATED: User-triggered deprecation notice
    user_deprecated = c.E_USER_DEPRECATED,
    _,

    /// Return whether this value contains any bit in `mask`.
    pub inline fn matches(self: Level, mask: c_int) bool {
        return (@backingInt(self) & mask) != 0;
    }

    /// Return whether this value contains a core error-level bit.
    pub inline fn isCore(self: Level) bool {
        return self.matches(c.E_CORE);
    }

    /// Return whether this value contains a fatal error-level bit.
    pub inline fn isFatal(self: Level) bool {
        return self.matches(c.E_FATAL_ERRORS);
    }
};

/// A borrowed view of PHP's most recently recorded E_* error.
/// Copy message/file before PHP replaces or clears the record, or the request ends.
pub const LastError = struct {
    level: Level,
    message: [:0]const u8,
    file: ?[:0]const u8,
    line: u32,
};

/// Read the same record as PHP's error_get_last(), or null when none exists.
/// Does not allocate, consume the record, or inspect the pending Throwable.
/// This reads recorded diagnostics; it does not catch fatal errors or bailouts.
pub fn last() ?LastError {
    const pg = globals.php().ptr();
    const message = pg.last_error_message orelse return null;
    return .{
        .level = @fromBackingInt(pg.last_error_type),
        .message = zend.String.from(message).slice(),
        .file = if (pg.last_error_file) |file| zend.String.from(file).slice() else null,
        .line = @intCast(pg.last_error_lineno),
    };
}

/// Trigger a PHP error
pub inline fn err(level: Level, comptime format: [:0]const u8, args: anytype) void {
    @call(.auto, c.zend_error, .{ @backingInt(level), format.ptr } ++ args);
}

/// Trigger a deprecation warning
pub inline fn deprecated(comptime format: [:0]const u8, args: anytype) void {
    err(.deprecated, format, args);
}

/// Trigger a warning
pub inline fn warning(comptime format: [:0]const u8, args: anytype) void {
    err(.warning, format, args);
}

/// Trigger a notice
pub inline fn notice(comptime format: [:0]const u8, args: anytype) void {
    err(.notice, format, args);
}

test {
    @import("std").testing.refAllDecls(@This());
}
