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

pub inline fn run(
    comptime Return: type,
    comptime Context: type,
    context: *Context,
    comptime callback: fn (*Context) Return,
) Error!Return {
    return runImpl(false, Return, Context, context, callback);
}

pub inline fn runFirst(
    comptime Return: type,
    comptime Context: type,
    context: *Context,
    comptime callback: fn (*Context) Return,
) Error!Return {
    return runImpl(true, Return, Context, context, callback);
}

pub inline fn runSimple(comptime callback: fn () void) Error!void {
    return runSimpleImpl(false, callback);
}

pub inline fn runFirstSimple(comptime callback: fn () void) Error!void {
    return runSimpleImpl(true, callback);
}

inline fn runImpl(
    comptime first: bool,
    comptime Return: type,
    comptime Context: type,
    context: *Context,
    comptime callback: fn (*Context) Return,
) Error!Return {
    const Frame = if (Return == void) struct {
        context: *Context,
    } else struct {
        context: *Context,
        result: Return = undefined,
    };

    const Wrapper = struct {
        fn call(raw: ?*anyopaque) callconv(.c) void {
            const frame: *Frame = @ptrCast(@alignCast(raw.?));
            if (comptime Return == void) {
                callback(frame.context);
            } else {
                frame.result = callback(frame.context);
            }
        }
    };

    var frame: Frame = .{ .context = context };
    if (comptime first)
        try runFirstRaw(Wrapper.call, &frame)
    else
        try runRaw(Wrapper.call, &frame);

    if (comptime Return == void) return;
    return frame.result;
}

inline fn runSimpleImpl(
    comptime first: bool,
    comptime callback: fn () void,
) Error!void {
    const Wrapper = struct {
        fn call(_: ?*anyopaque) callconv(.c) void {
            callback();
        }
    };

    if (comptime first)
        try runFirstRaw(Wrapper.call, null)
    else
        try runRaw(Wrapper.call, null);
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
    };

    try std.testing.expect(@TypeOf(run(void, Context, undefined, Context.callback)) == Error!void);
    try std.testing.expect(@TypeOf(runFirst(void, Context, undefined, Context.callback)) == Error!void);
    try std.testing.expect(@TypeOf(run(u32, Context, undefined, Context.callbackValue)) == Error!u32);
    try std.testing.expect(@TypeOf(runFirst(u32, Context, undefined, Context.callbackValue)) == Error!u32);
}

test "raw API" {
    const Callback = struct {
        fn callback(_: ?*anyopaque) callconv(.c) void {}
    };

    try std.testing.expect(@TypeOf(runRaw(Callback.callback, null)) == Error!void);
    try std.testing.expect(@TypeOf(runFirstRaw(Callback.callback, null)) == Error!void);
}

test "simple API" {
    const Callback = struct {
        fn callback() void {}
    };

    try std.testing.expect(@TypeOf(runSimple(Callback.callback)) == Error!void);
    try std.testing.expect(@TypeOf(runFirstSimple(Callback.callback)) == Error!void);
}
