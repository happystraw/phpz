//! PHP Throwable state and the internal unwind signal.
//! Includes both Exception and Error subclasses (TypeError, ValueError, etc.),
//! which share Zend's EG(exception). E_* diagnostics belong to errors.zig.
//! The unwind signal covers exit/die and, on supported PHP versions, delayed OOM.
const phpz = @import("root.zig");
const c = phpz.c;
const globals = phpz.globals;
const zend = @import("zend.zig");
const errors = @import("errors.zig");

/// PHP exceptions and the internal unwind signal. Both remain pending in Zend.
/// Ordinary Throwables share PhpException; inspect get() for their PHP class.
/// UnwindExit can indicate exit/die or delayed OOM.
/// Propagate UnwindExit after native cleanup; do not resume normal PHP execution.
pub const Error = error{ PhpException, UnwindExit };

/// Throw a PHP TypeError and return its Zig error marker.
pub fn typeError(comptime format: [:0]const u8, args: anytype) Error {
    @branchHint(.cold);
    @call(.auto, c.zend_type_error, .{format.ptr} ++ args);
    return pending() orelse error.PhpException;
}

/// Return an argument type error
pub fn argumentTypeError(arg_num: u32, comptime format: [:0]const u8, args: anytype) Error {
    @branchHint(.cold);
    @call(.auto, c.zend_argument_type_error, .{ arg_num, format.ptr } ++ args);
    return pending() orelse error.PhpException;
}

/// Report a parameter type error using Zend's message (1-based arg_num).
pub fn wrongParameterType(arg_num: u32, expected: c.zend_expected_type, zv: *c.zval) Error {
    @branchHint(.cold);
    c.zend_wrong_parameter_type_error(arg_num, expected, zv);
    return pending() orelse error.PhpException;
}

/// Return an argument value error
pub fn argumentValueError(arg_num: u32, comptime format: [:0]const u8, args: anytype) Error {
    @branchHint(.cold);
    @call(.auto, c.zend_argument_value_error, .{ arg_num, format.ptr } ++ args);
    return pending() orelse error.PhpException;
}

/// Report extra named arguments unsupported by the current parameter parser.
pub fn unexpectedExtraNamedArgs() Error {
    @branchHint(.cold);
    c.zend_unexpected_extra_named_error();
    return pending() orelse error.PhpException;
}

/// Return an argument count error
pub fn argumentCountError(comptime format: [:0]const u8, args: anytype) Error {
    @branchHint(.cold);
    @call(.auto, c.zend_argument_count_error, .{format.ptr} ++ args);
    return pending() orelse error.PhpException;
}

/// Report wrong number of parameters — PHP generates the message automatically.
/// min: minimum expected parameters, max: maximum expected parameters (0 = unlimited).
pub fn wrongParameterCount(min: u32, max: u32) Error {
    @branchHint(.cold);
    c.zend_wrong_parameters_count_error(min, max);
    return pending() orelse error.PhpException;
}

/// Report that the function expects no parameters.
pub fn wrongParametersNone() Error {
    @branchHint(.cold);
    c.zend_wrong_parameters_none_error();
    return pending() orelse error.PhpException;
}

/// Throw a PHP Error and return its Zig error marker.
pub fn throwError(ce: ?*zend.ClassEntry, comptime format: [:0]const u8, args: anytype) Error {
    @branchHint(.cold);
    @call(.auto, c.zend_throw_error, .{ if (ce) |e| e.ptr() else null, format.ptr } ++ args);
    return pending() orelse error.PhpException;
}

/// PHP's executor exit status.
pub const ExitStatus = enum(c_int) { ok = 0, _ };

/// Throw a PHP exception and return its Zig error marker.
pub fn throwException(ce: *zend.ClassEntry, message: [:0]const u8, code: i64) Error {
    // Zend preserves a pending UnwindExit instead of replacing it.
    _ = throwExceptionObject(ce, message, code);
    return pending() orelse error.PhpException;
}

/// Throw a PHP exception with a formatted message and return its Zig error marker.
pub fn throwExceptionEx(ce: *zend.ClassEntry, code: i64, comptime format: [:0]const u8, args: anytype) Error {
    _ = throwExceptionObjectEx(ce, code, format, args);
    return pending() orelse error.PhpException;
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
pub inline fn hasPending() bool {
    return globals.executor().exception() != null;
}

/// Get the pending PHP exception object (EG(exception)). Returns null if no exception is set.
pub inline fn get() ?*zend.Object {
    return globals.executor().exception();
}

/// Classify the pending PHP exception without consuming it or changing exit status.
pub inline fn pending() ?Error {
    const ex = get() orelse return null;
    return if (isUnwindExit(ex)) error.UnwindExit else error.PhpException;
}

/// Return the pending PHP exception's Zig error marker, preserving Zend state.
pub inline fn check() Error!void {
    if (pending()) |pending_error| return pending_error;
}

/// Check whether an exception is PHP's internal unwind signal.
/// This identifies the signal, not its cause: exit/die or delayed OOM.
pub inline fn isUnwindExit(ex: *zend.Object) bool {
    return c.zend_is_unwind_exit(ex.ptr());
}

/// Consume a pending PHP unwind signal and return the current exit status.
/// The signal can come from exit/die or delayed OOM; consuming it does not recover the request.
/// Returns null without changing an ordinary exception or the exit status.
/// The host must still finish request shutdown and check its final exit status.
pub fn takeUnwindExit() ?ExitStatus {
    const ex = get() orelse return null;
    if (!isUnwindExit(ex)) return null;
    const status = globals.executor().exitStatus();
    clear();
    return status;
}

/// Clear the pending PHP exception. Does nothing if no exception is set.
pub const clear = c.zend_clear_exception;

/// Report and consume the pending PHP exception; does nothing if none is pending.
/// Reporting may run PHP code such as __toString() and can bail out.
pub fn report(level: errors.Level) void {
    const ex = get() orelse return;
    _ = c.zend_exception_error(ex.ptr(), @backingInt(level));
}

test {
    @import("std").testing.refAllDecls(@This());
}
