const std = @import("std");
const c = @import("../c.zig").c;

pub const TryCatchError = error{ZendBailout};
pub const TryCatchRawCallback = *const fn (?*anyopaque) callconv(.c) void;

pub inline fn tryCatchRaw(callback: TryCatchRawCallback, context: ?*anyopaque) TryCatchError!void {
    if (c.phpz_zend_try_catch(callback, context)) return error.ZendBailout;
}

pub inline fn firstTryCatchRaw(callback: TryCatchRawCallback, context: ?*anyopaque) TryCatchError!void {
    if (c.phpz_zend_first_try_catch(callback, context)) return error.ZendBailout;
}

pub inline fn tryCatch(comptime Context: type, context: *Context, comptime callback: fn (*Context) void) TryCatchError!void {
    return tryCatchTyped(void, Context, context, callback);
}

pub inline fn firstTryCatch(comptime Context: type, context: *Context, comptime callback: fn (*Context) void) TryCatchError!void {
    return firstTryCatchTyped(void, Context, context, callback);
}

pub inline fn tryCatchTyped(comptime Return: type, comptime Context: type, context: *Context, comptime callback: fn (*Context) Return) TryCatchError!Return {
    return tryCatchTypedImpl(false, Return, Context, context, callback);
}

pub inline fn firstTryCatchTyped(comptime Return: type, comptime Context: type, context: *Context, comptime callback: fn (*Context) Return) TryCatchError!Return {
    return tryCatchTypedImpl(true, Return, Context, context, callback);
}

pub inline fn tryCatchSimple(comptime callback: fn () void) TryCatchError!void {
    return tryCatchSimpleTyped(false, callback);
}

pub inline fn firstTryCatchSimple(comptime callback: fn () void) TryCatchError!void {
    return tryCatchSimpleTyped(true, callback);
}

inline fn tryCatchTypedImpl(
    comptime first: bool,
    comptime Return: type,
    comptime Context: type,
    context: *Context,
    comptime callback: fn (*Context) Return,
) TryCatchError!Return {
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
        try firstTryCatchRaw(Wrapper.call, &frame)
    else
        try tryCatchRaw(Wrapper.call, &frame);

    if (comptime Return == void) return;
    return frame.result;
}

inline fn tryCatchSimpleTyped(
    comptime first: bool,
    comptime callback: fn () void,
) TryCatchError!void {
    const Wrapper = struct {
        fn call(_: ?*anyopaque) callconv(.c) void {
            callback();
        }
    };

    if (comptime first)
        try firstTryCatchRaw(Wrapper.call, null)
    else
        try tryCatchRaw(Wrapper.call, null);
}

test {
    std.testing.refAllDecls(@This());
}

test "tryCatch typed API" {
    const Context = struct {
        value: u32,

        fn callback(self: *@This()) void {
            self.value += 1;
        }

        fn callbackValue(self: *@This()) u32 {
            return self.value;
        }
    };

    try std.testing.expect(@TypeOf(tryCatch(Context, undefined, Context.callback)) == TryCatchError!void);
    try std.testing.expect(@TypeOf(firstTryCatch(Context, undefined, Context.callback)) == TryCatchError!void);
    try std.testing.expect(@TypeOf(tryCatchTyped(u32, Context, undefined, Context.callbackValue)) == TryCatchError!u32);
    try std.testing.expect(@TypeOf(firstTryCatchTyped(u32, Context, undefined, Context.callbackValue)) == TryCatchError!u32);
}

test "tryCatch raw API" {
    const Callback = struct {
        fn callback(_: ?*anyopaque) callconv(.c) void {}
    };

    try std.testing.expect(@TypeOf(tryCatchRaw(Callback.callback, null)) == TryCatchError!void);
    try std.testing.expect(@TypeOf(firstTryCatchRaw(Callback.callback, null)) == TryCatchError!void);
}

test "tryCatch simple API" {
    const Callback = struct {
        fn callback() void {}
    };

    try std.testing.expect(@TypeOf(tryCatchSimple(Callback.callback)) == TryCatchError!void);
    try std.testing.expect(@TypeOf(firstTryCatchSimple(Callback.callback)) == TryCatchError!void);
}
