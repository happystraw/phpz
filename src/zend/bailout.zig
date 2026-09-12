const std = @import("std");
const c = @import("../c.zig").c;

pub const Error = error{ZendBailout};
pub const RawCallback = *const fn (?*anyopaque) callconv(.c) void;

pub inline fn raise() noreturn {
    c.phpz_zend_bailout();
    unreachable;
}

pub inline fn runRaw(callback: RawCallback, context: ?*anyopaque) Error!void {
    if (c.phpz_zend_try_catch(callback, context)) return error.ZendBailout;
}

pub inline fn runFirstRaw(callback: RawCallback, context: ?*anyopaque) Error!void {
    if (c.phpz_zend_first_try_catch(callback, context)) return error.ZendBailout;
}

/// Invoke a comptime-known callback with a value or pointer context under zend_try.
/// Returns error.ZendBailout on bailout; skipped Zig defer/errdefer do not run.
pub inline fn run(comptime callback: anytype, context: anytype) Error!@TypeOf(callback(context)) {
    return runImpl(callback, context, false);
}

/// Like run, but clears the previous bailout target with zend_first_try.
/// Use only at the outermost bailout boundary.
pub inline fn runFirst(comptime callback: anytype, context: anytype) Error!@TypeOf(callback(context)) {
    return runImpl(callback, context, true);
}

pub inline fn runWithoutArgs(comptime callback: fn () void) Error!void {
    return runWithoutArgsImpl(callback, false);
}

pub inline fn runFirstWithoutArgs(comptime callback: fn () void) Error!void {
    return runWithoutArgsImpl(callback, true);
}

inline fn runImpl(
    comptime callback: anytype,
    context: anytype,
    comptime first: bool,
) Error!@TypeOf(callback(context)) {
    const Frame = struct {
        context: @TypeOf(context),
        result: @TypeOf(callback(context)) = undefined,
    };

    const Handler = struct {
        fn call(user_data: ?*anyopaque) callconv(.c) void {
            const frame: *Frame = @ptrCast(@alignCast(user_data.?));
            frame.result = callback(frame.context);
        }
    };

    var frame: Frame = .{ .context = context };
    if (comptime first)
        try runFirstRaw(Handler.call, &frame)
    else
        try runRaw(Handler.call, &frame);

    return frame.result;
}

inline fn runWithoutArgsImpl(comptime callback: fn () void, comptime first: bool) Error!void {
    const Handler = struct {
        fn call(_: ?*anyopaque) callconv(.c) void {
            callback();
        }
    };

    if (comptime first)
        try runFirstRaw(Handler.call, null)
    else
        try runRaw(Handler.call, null);
}

test {
    std.testing.refAllDecls(@This());
}

test "run API" {
    const Context = struct {
        value: u32,

        fn callback(self: *@This()) void {
            self.value += 1;
        }

        fn callbackValue(self: *@This()) u32 {
            return self.value;
        }

        fn byValue(self: @This()) u32 {
            return self.value;
        }
    };

    try std.testing.expect(@TypeOf(run(Context.callback, @as(*Context, undefined))) == Error!void);
    try std.testing.expect(@TypeOf(runFirst(Context.callback, @as(*Context, undefined))) == Error!void);
    try std.testing.expect(@TypeOf(run(Context.callbackValue, @as(*Context, undefined))) == Error!u32);
    try std.testing.expect(@TypeOf(runFirst(Context.callbackValue, @as(*Context, undefined))) == Error!u32);
    try std.testing.expect(@TypeOf(run(Context.byValue, @as(Context, undefined))) == Error!u32);
    try std.testing.expect(@TypeOf(runFirst(Context.byValue, @as(Context, undefined))) == Error!u32);
}

test "run preserves callback error unions" {
    const Callback = struct {
        fn value(input: u32) !u32 {
            if (input == 0) return error.CallbackFailed;
            return input;
        }

        fn pointer(input: *const u32) error{CallbackFailed}!u32 {
            return value(input.*);
        }

        fn noValue(_: u32) anyerror!void {}
    };

    const ValueResult = Error!(error{CallbackFailed}!u32);
    const VoidResult = Error!(anyerror!void);
    try std.testing.expect(@TypeOf(run(Callback.value, @as(u32, 42))) == ValueResult);
    try std.testing.expect(@TypeOf(runFirst(Callback.value, @as(u32, 42))) == ValueResult);
    try std.testing.expect(@TypeOf(run(Callback.pointer, @as(*const u32, undefined))) == ValueResult);
    try std.testing.expect(@TypeOf(runFirst(Callback.pointer, @as(*const u32, undefined))) == ValueResult);
    try std.testing.expect(@TypeOf(run(Callback.noValue, @as(u32, 0))) == VoidResult);
    try std.testing.expect(@TypeOf(runFirst(Callback.noValue, @as(u32, 0))) == VoidResult);
}

test "raw API" {
    const Callback = struct {
        fn callback(_: ?*anyopaque) callconv(.c) void {}
    };

    try std.testing.expect(@TypeOf(runRaw(Callback.callback, null)) == Error!void);
    try std.testing.expect(@TypeOf(runFirstRaw(Callback.callback, null)) == Error!void);
}

test "without args API" {
    const Callback = struct {
        fn callback() void {}
    };

    try std.testing.expect(@TypeOf(runWithoutArgs(Callback.callback)) == Error!void);
    try std.testing.expect(@TypeOf(runFirstWithoutArgs(Callback.callback)) == Error!void);
}
