const c = @import("root.zig").c;
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
};

pub const ArgumentTypeError = error{PhpArgumentTypeError};

/// Return an argument type error
pub inline fn argumentTypeError(arg_num: u32, comptime format: [:0]const u8, args: anytype) ArgumentTypeError {
    @branchHint(.cold);
    @call(.auto, c.zend_argument_type_error, .{ arg_num, format.ptr } ++ args);
    return error.PhpArgumentTypeError;
}

pub const ArgumentValueError = error{PhpArgumentValueError};

/// Return an argument value error
pub inline fn argumentValueError(arg_num: u32, comptime format: [:0]const u8, args: anytype) ArgumentValueError {
    @branchHint(.cold);
    @call(.auto, c.zend_argument_value_error, .{ arg_num, format.ptr } ++ args);
    return error.PhpArgumentValueError;
}

pub const ArgumentCountError = error{PhpArgumentCountError};

/// Return an argument count error
pub inline fn argumentCountError(comptime format: [:0]const u8, args: anytype) ArgumentCountError {
    @branchHint(.cold);
    @call(.auto, c.zend_argument_count_error, .{format.ptr} ++ args);
    return error.PhpArgumentCountError;
}

pub const WrongParameterCountError = error{PhpWrongParameterCountError};

/// Report wrong number of parameters — PHP generates the message automatically.
/// min: minimum expected parameters, max: maximum expected parameters (0 = unlimited).
pub inline fn wrongParameterCount(min: u32, max: u32) WrongParameterCountError {
    @branchHint(.cold);
    c.zend_wrong_parameters_count_error(min, max);
    return error.PhpWrongParameterCountError;
}

/// Report that the function expects no parameters.
pub inline fn wrongParametersNone() WrongParameterCountError {
    @branchHint(.cold);
    c.zend_wrong_parameters_none_error();
    return error.PhpWrongParameterCountError;
}

/// Throw a PHP Error
pub fn throwError(ce: ?*zend.ClassEntry, comptime format: [:0]const u8, args: anytype) void {
    @call(.auto, c.zend_throw_error, .{ if (ce) |e| e.ptr() else null, format.ptr } ++ args);
}

/// Throw a PHP exception
pub fn throwException(ce: *zend.ClassEntry, message: [:0]const u8, code: i64) ?*zend.Object {
    const obj = c.zend_throw_exception(ce.ptr(), message.ptr, @intCast(code));
    return if (obj) |o| zend.Object.from(o) else null;
}

/// Throw a PHP exception with formatted message and error code
pub fn throwExceptionEx(ce: *zend.ClassEntry, code: i64, comptime format: [:0]const u8, args: anytype) ?*zend.Object {
    const obj = @call(.auto, c.zend_throw_exception_ex, .{ ce.ptr(), @as(c.zend_long, @intCast(code)), format.ptr } ++ args);
    return if (obj) |o| zend.Object.from(o) else null;
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
