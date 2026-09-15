const std = @import("std");
const c = @import("../c.zig").c;

pub const Error = error{ZendBailout};
const RawCallback = *const fn (?*anyopaque) callconv(.c) void;

fn Result(comptime Callback: type) type {
    const R = @typeInfo(Callback).@"fn".return_type.?;
    return switch (@typeInfo(R)) {
        .error_union => |eu| (eu.error_set || Error)!eu.payload,
        else => Error!R,
    };
}

pub inline fn raise() noreturn {
    c.phpz_zend_bailout();
    unreachable;
}

inline fn runRaw(callback: RawCallback, context: ?*anyopaque) Error!void {
    if (c.phpz_zend_try_catch(callback, context)) return error.ZendBailout;
}

inline fn runFirstRaw(callback: RawCallback, context: ?*anyopaque) Error!void {
    if (c.phpz_zend_first_try_catch(callback, context)) return error.ZendBailout;
}

/// Invoke a comptime-known callback with an argument tuple under zend_try.
/// Merges callback errors with error.ZendBailout.
/// Returns error.ZendBailout on bailout; skipped Zig defer/errdefer do not run.
pub inline fn run(comptime callback: anytype, args: std.meta.ArgsTuple(@TypeOf(callback))) Result(@TypeOf(callback)) {
    return runImpl(callback, args, false);
}

/// Like run, but clears the previous bailout target with zend_first_try.
/// Use only at the outermost bailout boundary.
pub inline fn runFirst(comptime callback: anytype, args: std.meta.ArgsTuple(@TypeOf(callback))) Result(@TypeOf(callback)) {
    return runImpl(callback, args, true);
}

inline fn runImpl(
    comptime callback: anytype,
    args: std.meta.ArgsTuple(@TypeOf(callback)),
    comptime first: bool,
) Result(@TypeOf(callback)) {
    const info = @typeInfo(@TypeOf(callback)).@"fn";
    const Frame = struct {
        args: std.meta.ArgsTuple(@TypeOf(callback)),
        retval: info.return_type.? = undefined,
    };

    const Handler = struct {
        fn call(user_data: ?*anyopaque) callconv(.c) void {
            const frame: *Frame = @ptrCast(@alignCast(user_data.?));
            frame.retval = @call(.auto, callback, frame.args);
        }
    };

    var frame: Frame = .{ .args = args };
    if (comptime first)
        try runFirstRaw(Handler.call, &frame)
    else
        try runRaw(Handler.call, &frame);

    return frame.retval;
}

test {
    std.testing.refAllDecls(@This());
}

test "run API" {
    const TestContext = struct {
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

        fn withVoid(_: void) u32 {
            return 42;
        }
    };

    try std.testing.expect(@TypeOf(run(TestContext.callback, .{@as(*TestContext, undefined)})) == Error!void);
    try std.testing.expect(@TypeOf(runFirst(TestContext.callback, .{@as(*TestContext, undefined)})) == Error!void);
    try std.testing.expect(@TypeOf(run(TestContext.callbackValue, .{@as(*TestContext, undefined)})) == Error!u32);
    try std.testing.expect(@TypeOf(runFirst(TestContext.callbackValue, .{@as(*TestContext, undefined)})) == Error!u32);
    try std.testing.expect(@TypeOf(run(TestContext.byValue, .{@as(TestContext, undefined)})) == Error!u32);
    try std.testing.expect(@TypeOf(runFirst(TestContext.byValue, .{@as(TestContext, undefined)})) == Error!u32);
    try std.testing.expectEqual(@as(u32, 42), try run(TestContext.byValue, .{.{ .value = 42 }}));
    try std.testing.expectEqual(@as(u32, 42), try runFirst(TestContext.byValue, .{.{ .value = 42 }}));
    try std.testing.expectEqual(@as(u32, 42), try run(TestContext.withVoid, .{{}}));
    try std.testing.expectEqual(@as(u32, 42), try runFirst(TestContext.withVoid, .{{}}));
}

test "run merges callback errors" {
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

    comptime {
        const ValueResult = error{ CallbackFailed, ZendBailout }!u32;
        const VoidResult = anyerror!void;
        try std.testing.expect(@TypeOf(run(Callback.value, .{@as(u32, 42)})) == ValueResult);
        try std.testing.expect(@TypeOf(runFirst(Callback.value, .{@as(u32, 42)})) == ValueResult);
        try std.testing.expect(@TypeOf(run(Callback.pointer, .{@as(*const u32, undefined)})) == ValueResult);
        try std.testing.expect(@TypeOf(runFirst(Callback.pointer, .{@as(*const u32, undefined)})) == ValueResult);
        try std.testing.expect(@TypeOf(run(Callback.noValue, .{@as(u32, 0)})) == VoidResult);
        try std.testing.expect(@TypeOf(runFirst(Callback.noValue, .{@as(u32, 0)})) == VoidResult);
    }
}

test "raw API" {
    const Callback = struct {
        fn callback(_: ?*anyopaque) callconv(.c) void {}
    };

    try std.testing.expect(@TypeOf(runRaw(Callback.callback, null)) == Error!void);
    try std.testing.expect(@TypeOf(runFirstRaw(Callback.callback, null)) == Error!void);
}

test "multiple arguments" {
    const Callback = struct {
        fn update(value: *u32, increment: u32, fail: bool) !u32 {
            if (fail) return error.CallbackFailed;
            value.* += increment;
            return value.*;
        }
    };

    inline for (.{ run, runFirst }) |invoke| {
        comptime {
            try std.testing.expect(@TypeOf(invoke(Callback.update, .{ @as(*u32, undefined), 2, false })) == error{ CallbackFailed, ZendBailout }!u32);
        }
        var value: u32 = 40;
        try std.testing.expectEqual(@as(u32, 42), try invoke(Callback.update, .{ &value, 2, false }));
        try std.testing.expectEqual(@as(u32, 42), value);
        try std.testing.expectError(error.CallbackFailed, invoke(Callback.update, .{ &value, 10, true }));
        try std.testing.expectEqual(@as(u32, 42), value);
    }
}

test "without args API" {
    const Callback = struct {
        fn callback() void {}

        fn value() u32 {
            return 42;
        }

        fn fallibleValue() !u32 {
            return error.CallbackFailed;
        }

        fn fallibleVoid() error{CallbackFailed}!void {
            return error.CallbackFailed;
        }

        fn noValue() anyerror!void {}
    };

    comptime {
        const CallbackError = error{ CallbackFailed, ZendBailout };
        try std.testing.expect(@TypeOf(run(Callback.callback, .{})) == Error!void);
        try std.testing.expect(@TypeOf(runFirst(Callback.callback, .{})) == Error!void);
        try std.testing.expect(@TypeOf(run(Callback.value, .{})) == Error!u32);
        try std.testing.expect(@TypeOf(runFirst(Callback.value, .{})) == Error!u32);
        try std.testing.expect(@TypeOf(run(Callback.fallibleValue, .{})) == CallbackError!u32);
        try std.testing.expect(@TypeOf(runFirst(Callback.fallibleValue, .{})) == CallbackError!u32);
        try std.testing.expect(@TypeOf(run(Callback.fallibleVoid, .{})) == CallbackError!void);
        try std.testing.expect(@TypeOf(runFirst(Callback.fallibleVoid, .{})) == CallbackError!void);
        try std.testing.expect(@TypeOf(run(Callback.noValue, .{})) == anyerror!void);
        try std.testing.expect(@TypeOf(runFirst(Callback.noValue, .{})) == anyerror!void);
    }

    inline for (.{ run, runFirst }) |invoke| {
        try invoke(Callback.callback, .{});
        try std.testing.expectEqual(@as(u32, 42), try invoke(Callback.value, .{}));
        try std.testing.expectError(error.CallbackFailed, invoke(Callback.fallibleValue, .{}));
        try std.testing.expectError(error.CallbackFailed, invoke(Callback.fallibleVoid, .{}));
        try invoke(Callback.noValue, .{});
    }
}
