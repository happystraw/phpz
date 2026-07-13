const std = @import("std");

const c = @import("root.zig").c;
const Ctx = @import("Ctx.zig");
const errors = @import("errors.zig");
const zend = @import("zend.zig");
const Zval = @import("zval.zig").Zval;

/// Function-call observer callbacks.
///
/// `filter` runs when Zend first installs handlers for a function. Zend caches
/// the result, so it must not depend on per-call or mutable request state.
pub const Fcall = struct {
    filter: ?fn (*zend.Function) bool = null,
    begin: ?fn (*Ctx.Call) void = null,
    end: ?fn (*Ctx.Call, ?*Zval) void = null,
};

/// Error observer callbacks.
pub const Error = struct {
    filter: ?fn (errors.Level) bool = null,
    observe: fn (Info) void,

    /// Borrowed error data passed to an error observer.
    ///
    /// `filename` and `message` are valid only for the duration of the callback.
    pub const Info = struct {
        message: [:0]const u8,
        file: ?[:0]const u8,
        line: u32,
        level: errors.Level,
    };
};

/// Exception observer callback.
///
/// The exception object is borrowed and is valid for the duration of the
/// callback. Use `addref()` if it must be retained.
pub const Exception = struct {
    observe: fn (*zend.Object) void,
};

/// Observer configuration registered during module startup.
pub const Config = struct {
    fcall: ?Fcall = null,
    errors: ?Error = null,
    exception: ?Exception = null,
};

fn FcallAdapter(comptime config: Fcall) type {
    if (config.begin == null and config.end == null) {
        @compileError("observer fcall requires at least one begin or end callback");
    }

    return struct {
        fn init(execute_data: ?*c.zend_execute_data) callconv(.c) c.zend_observer_fcall_handlers {
            const call = Ctx.Call.from(execute_data.?);
            const function = call.function() orelse return .{ .begin = null, .end = null };
            if (config.filter) |filter| {
                if (!filter(function)) return .{ .begin = null, .end = null };
            }
            return .{
                .begin = if (config.begin != null) &begin else null,
                .end = if (config.end != null) &end else null,
            };
        }

        fn begin(execute_data: ?*c.zend_execute_data) callconv(.c) void {
            if (config.begin) |callback| {
                callback(.from(execute_data.?));
            }
        }

        fn end(execute_data: ?*c.zend_execute_data, retval: ?*c.zval) callconv(.c) void {
            if (config.end) |callback| {
                callback(
                    .from(execute_data.?),
                    if (retval) |zv| .from(zv) else null,
                );
            }
        }

        fn register() void {
            c.zend_observer_fcall_register(&init);
        }
    };
}

fn ErrorAdapter(comptime config: Error) type {
    return struct {
        fn stringSlice(raw: ?*c.zend_string) ?[:0]const u8 {
            if (raw == null) return null;
            return zend.String.from(@ptrCast(raw)).slice();
        }

        fn callback(
            error_type: c_int,
            error_filename: ?*c.zend_string,
            error_line: u32,
            message: ?*c.zend_string,
        ) callconv(.c) void {
            const level: errors.Level = @enumFromInt(error_type);
            if (config.filter) |filter| {
                if (!filter(level)) return;
            }
            config.observe(.{
                .level = level,
                .file = if (error_filename) |s| zend.String.slice(.from(s)) else null,
                .line = error_line,
                .message = if (message) |s| zend.String.slice(.from(s)) else "",
            });
        }

        fn register() void {
            c.zend_observer_error_register(&callback);
        }
    };
}

fn ExceptionAdapter(comptime config: Exception) type {
    return struct {
        const Hook = *const fn (?*c.zend_object) callconv(.c) void;

        var previous: ?Hook = null;
        var installed = false;

        fn callback(exception: ?*c.zend_object) callconv(.c) void {
            config.observe(zend.Object.from(exception.?));
            if (previous) |previous_hook| {
                previous_hook(exception);
            }
        }

        fn register() void {
            if (installed) return;
            previous = c.zend_throw_exception_hook;
            c.zend_throw_exception_hook = &callback;
            installed = true;
        }

        fn unregister() void {
            if (installed and c.zend_throw_exception_hook == &callback) {
                c.zend_throw_exception_hook = previous;
            }
            installed = false;
            previous = null;
        }
    };
}

/// Register configured observers during MINIT.
pub fn startup(comptime config: Config) void {
    if (comptime config.fcall) |fcall| {
        FcallAdapter(fcall).register();
    }
    if (comptime config.errors) |error_config| {
        ErrorAdapter(error_config).register();
    }
    if (comptime config.exception) |exception| {
        ExceptionAdapter(exception).register();
    }
}

/// Restore hooks owned by this module during MSHUTDOWN.
///
/// Zend does not expose unregister functions for fcall or error observers.
pub fn shutdown(comptime config: Config) void {
    if (comptime config.exception) |exception| {
        ExceptionAdapter(exception).unregister();
    }
}

test {
    std.testing.refAllDecls(@This());
}
