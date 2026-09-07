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

pub const TypeError = error{PhpTypeError};

/// Throw a PHP TypeError and return its Zig error marker.
pub fn typeError(comptime format: [:0]const u8, args: anytype) TypeError {
    @branchHint(.cold);
    @call(.auto, c.zend_type_error, .{format.ptr} ++ args);
    return error.PhpTypeError;
}

pub const ArgumentTypeError = error{PhpArgumentTypeError};

/// Return an argument type error
pub fn argumentTypeError(arg_num: u32, comptime format: [:0]const u8, args: anytype) ArgumentTypeError {
    @branchHint(.cold);
    @call(.auto, c.zend_argument_type_error, .{ arg_num, format.ptr } ++ args);
    return error.PhpArgumentTypeError;
}

pub const ArgumentValueError = error{PhpArgumentValueError};

/// Return an argument value error
pub fn argumentValueError(arg_num: u32, comptime format: [:0]const u8, args: anytype) ArgumentValueError {
    @branchHint(.cold);
    @call(.auto, c.zend_argument_value_error, .{ arg_num, format.ptr } ++ args);
    return error.PhpArgumentValueError;
}

pub const ArgumentCountError = error{PhpArgumentCountError};

/// Return an argument count error
pub fn argumentCountError(comptime format: [:0]const u8, args: anytype) ArgumentCountError {
    @branchHint(.cold);
    @call(.auto, c.zend_argument_count_error, .{format.ptr} ++ args);
    return error.PhpArgumentCountError;
}

pub const WrongParameterCountError = error{PhpWrongParameterCountError};

/// Report wrong number of parameters — PHP generates the message automatically.
/// min: minimum expected parameters, max: maximum expected parameters (0 = unlimited).
pub fn wrongParameterCount(min: u32, max: u32) WrongParameterCountError {
    @branchHint(.cold);
    c.zend_wrong_parameters_count_error(min, max);
    return error.PhpWrongParameterCountError;
}

/// Report that the function expects no parameters.
pub fn wrongParametersNone() WrongParameterCountError {
    @branchHint(.cold);
    c.zend_wrong_parameters_none_error();
    return error.PhpWrongParameterCountError;
}

pub const Error = error{PhpError};

/// Throw a PHP Error and return its Zig error marker.
pub fn throwError(ce: ?*zend.ClassEntry, comptime format: [:0]const u8, args: anytype) Error {
    @branchHint(.cold);
    @call(.auto, c.zend_throw_error, .{ if (ce) |e| e.ptr() else null, format.ptr } ++ args);
    return error.PhpError;
}

pub const Exception = error{PhpException};

/// Throw a PHP exception and return its Zig error marker.
pub fn throwException(ce: *zend.ClassEntry, message: [:0]const u8, code: i64) Exception {
    _ = throwExceptionObject(ce, message, code);
    return error.PhpException;
}

/// Throw a PHP exception with a formatted message and return its Zig error marker.
pub fn throwExceptionEx(ce: *zend.ClassEntry, code: i64, comptime format: [:0]const u8, args: anytype) Exception {
    _ = throwExceptionObjectEx(ce, code, format, args);
    return error.PhpException;
}

/// Throw a PHP exception and return the object without adding a reference.
/// The PHP exception is pending; this function does not propagate a Zig error.
pub fn throwExceptionObject(ce: *zend.ClassEntry, message: [:0]const u8, code: i64) *zend.Object {
    @branchHint(.cold);
    const obj = c.zend_throw_exception(ce.ptr(), message.ptr, @intCast(code));
    return zend.Object.from(obj.?);
}

/// Throw a PHP exception with a formatted message and return the object without adding a reference.
/// The PHP exception is pending; this function does not propagate a Zig error.
pub fn throwExceptionObjectEx(ce: *zend.ClassEntry, code: i64, comptime format: [:0]const u8, args: anytype) *zend.Object {
    @branchHint(.cold);
    const obj = @call(.auto, c.zend_throw_exception_ex, .{ ce.ptr(), @as(c.zend_long, @intCast(code)), format.ptr } ++ args);
    return zend.Object.from(obj.?);
}

/// Check whether a PHP exception is pending (EG(exception) != null).
pub inline fn hasException() bool {
    return globals.executor().exception() != null;
}

/// Get the pending PHP exception object (EG(exception)). Returns null if no exception is set.
pub inline fn exception() ?*zend.Object {
    return globals.executor().exception();
}

/// Clear the pending PHP exception. Does nothing if no exception is set.
pub const clearException = c.zend_clear_exception;

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
