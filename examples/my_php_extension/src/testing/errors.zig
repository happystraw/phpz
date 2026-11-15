const std = @import("std");
const phpz = @import("phpz");

pub fn readLastError(clear_exception: bool) !?*phpz.zend.Array {
    if (clear_exception) {
        const thrown = phpz.exception.throwException(.internal("Exception"), "pending fixture", 0);
        const pending = phpz.exception.pending();
        phpz.exception.clear();
        try std.testing.expect(thrown == error.PhpException);
        try std.testing.expect(pending != null);
        try std.testing.expect(pending.? == error.PhpException);
        try std.testing.expect(!phpz.exception.hasPending());
    }
    const record = phpz.errors.last() orelse return null;
    var value = phpz.Zval.raw.undef;
    const result = phpz.Zval.Array.empty(&value);
    result.set(.int, "type", @backingInt(record.level));
    result.set(.string, "message", record.message);
    if (record.file) |file| result.set(.string, "file", file) else result.set(.null, "file", {});
    result.set(.int, "line", record.line);
    return result.zendArray();
}

/// Throw, then rethrow the pending exception the way opcache JIT frame
/// cleanup does: zend_throw_exception_internal(NULL) with an active frame
/// passes NULL to zend_throw_exception_hook.
pub fn rethrowPendingException() !void {
    phpz.exception.throwException(.internal("Exception"), "rethrown", 0) catch {};
    phpz.c.zend_throw_exception_internal(null);
    return error.PhpException;
}

/// Report the pending exception as a warning; report() is a no-op when nothing
/// is pending. Returns whether an exception is still pending afterwards.
pub fn reportPendingException() bool {
    phpz.exception.report(.warning);
    phpz.exception.throwException(.internal("Exception"), "reported", 0) catch {};
    phpz.exception.report(.warning);
    return phpz.exception.hasPending();
}
