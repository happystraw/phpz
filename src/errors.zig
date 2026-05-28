const c = @import("root.zig").c;

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
};

/// Return an argument type error
pub fn argumentTypeError(arg_num: comptime_int, comptime format: [:0]const u8, args: anytype) error{PhpArgumentTypeError}!void {
    @call(.auto, c.zend_argument_type_error, .{ arg_num, format.ptr } ++ args);
    return error.PhpArgumentTypeError;
}

/// Return an argument value error
pub fn argumentValueError(arg_num: comptime_int, comptime format: [:0]const u8, args: anytype) error{PhpArgumentValueError}!void {
    @call(.auto, c.zend_argument_value_error, .{ arg_num, format.ptr } ++ args);
    return error.PhpArgumentValueError;
}

/// Return an argument count error
pub fn argumentCountError(comptime format: [:0]const u8, args: anytype) error{PhpArgumentCountError}!void {
    @call(.auto, c.zend_argument_count_error, .{format.ptr} ++ args);
    return error.PhpArgumentCountError;
}

/// Throw a PHP Error
pub fn throwError(ce: ?*c.zend_class_entry, comptime format: [:0]const u8, args: anytype) void {
    @call(.auto, c.zend_throw_error, .{ ce, format.ptr } ++ args);
}

/// Throw a PHP exception
pub fn throwException(ce: ?*c.zend_class_entry, message: [:0]const u8) ?*c.zend_object {
    return c.zend_throw_exception(ce, message.ptr, 0);
}

/// Throw a PHP exception with formatted message and error code
pub fn throwExceptionEx(ce: ?*c.zend_class_entry, code: c.zend_long, comptime format: [:0]const u8, args: anytype) ?*c.zend_object {
    return @call(.auto, c.zend_throw_exception_ex, .{ ce, code, format.ptr } ++ args);
}

/// Check whether a PHP exception is pending (EG(exception) != null).
pub inline fn hasException() bool {
    return c.executor_globals.exception != null;
}

/// Clear the pending PHP exception. Does nothing if no exception is set.
pub const clearException = c.zend_clear_exception;

/// Trigger a PHP error
pub fn err(level: Level, comptime format: [:0]const u8, args: anytype) void {
    @call(.auto, c.zend_error, .{ @intFromEnum(level), format.ptr } ++ args);
}

/// Trigger a deprecation warning
pub fn deprecated(comptime format: [:0]const u8, args: anytype) void {
    err(.deprecated, format, args);
}

/// Trigger a warning
pub fn warning(comptime format: [:0]const u8, args: anytype) void {
    err(.warning, format, args);
}

/// Trigger a notice
pub fn notice(comptime format: [:0]const u8, args: anytype) void {
    err(.notice, format, args);
}

test {
    @import("std").testing.refAllDecls(@This());
}
