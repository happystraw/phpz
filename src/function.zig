const std = @import("std");

const c = @import("root.zig").c;
const ExecContext = @import("ExecContext.zig");
const Zval = @import("Zval.zig");

const PhpFn = fn (?*c.zend_execute_data, ?*c.zval) callconv(.c) void;
const PhpFnKind = enum { function, method };
const PhpFnCallConv = enum { standard, no_params, only_ctx, only_ret };
const PhpFnReturnKind = enum { error_union, scalar };
const PhpFnReturnType = union(PhpFnReturnKind) { error_union: Zval.Kind, scalar: Zval.Kind };
const PhpMethodKind = enum { object, static };

/// Register a Zig function as a PHP function.
///
/// This function creates a PHP function binding at compile time, allowing Zig code
/// to be called from PHP. The function signature is automatically analyzed and
/// adapted to match PHP's calling convention.
///
/// Supported function signatures:
///   - `fn (ctx: *ExecContext, ret: *Zval) !void` - Full control with parameters and return value
///   - `fn (ctx: *ExecContext) !void` - Only access parameters
///   - `fn (ret: *Zval) !void` - Only set return value
///   - `fn () !void` - No parameters or return value
///
/// Supported return types:
///   - `void` - No return value (PHP null)
///   - `!void` - Error union (throws PHP error on error)
///   - `int` or `!int` - PHP integer
///   - `bool` or `!bool` - PHP boolean
///   - `float` or `!float` - PHP float
///
/// Parameters:
///   - func_name: The name of the PHP function (null-terminated string)
///   - func: The Zig function to bind
///
/// Example:
/// ```zig
/// fn helloWorld() void {
///     _ = phpz.printf("Hello from ZIG!\n", .{});
/// }
///
/// fn add(ctx: *ExecContext, ret: *Zval) !void {
///     var a: i64 = undefined;
///     var b: i64 = undefined;
///     try ctx.parse("ll", .{ &a, &b });
///     ret.set(.int, a + b);
/// }
///
/// fn greet(ctx: *ExecContext, ret: *Zval) !void {
///     var name: []u8 = undefined;
///     try ctx.parse("s", .{ &name.ptr, &name.len });
///     const greeting = try std.fmt.allocPrint(allocator, "Hello, {s}!", .{name});
///     defer allocator.free(greeting);
///     ret.set(.string, greeting);
/// }
///
/// // In your module initialization:
/// comptime {
///     phpz.function("hello_world", helloWorld);
///     phpz.function("add", add);
///     phpz.function("greet", greet);
/// }
/// ```
pub fn function(comptime func_name: [:0]const u8, comptime func: anytype) void {
    comptime {
        exportPhpFn(
            .function,
            func_name,
            makePhpFn(func_name ++ "()", func),
        );
    }
}

/// Register a Zig function as a PHP class method.
///
/// Similar to `function`, but exports with `zim_` prefix instead of `zif_`.
/// Use `methodWithClass` if you need automatic static/object method detection.
pub fn method(comptime class_name: [:0]const u8, comptime func_name: [:0]const u8, comptime func: anytype) void {
    comptime {
        exportPhpFn(
            .method,
            makeMethodExportName(class_name, func_name),
            makePhpFn(class_name ++ "::" ++ func_name ++ "()", func),
        );
    }
}

/// Register a Zig function as a PHP class method with Class type.
///
/// Accepts a Class type (returned by `class.Class()`) which enables automatic
/// detection of static vs object methods based on the function signature.
pub fn methodWithClass(comptime Class: anytype, comptime func_name: [:0]const u8, comptime func: anytype) void {
    comptime {
        exportPhpFn(
            .method,
            makeMethodExportName(Class.name, func_name),
            makePhpMethod(Class, Class.name ++ "::" ++ func_name ++ "()", func),
        );
    }
}

fn makePhpFn(comptime func_desc: [:0]const u8, comptime func: anytype) PhpFn {
    const call_conv = comptime detectPhpFnCallConv(func);
    return struct {
        fn @"fn"(execute_data: ?*c.zend_execute_data, return_value: ?*c.zval) callconv(.c) void {
            var ctx = ExecContext.init(execute_data.?);
            var ret = Zval.from(return_value.?);
            const args = switch (call_conv) {
                .standard => .{ &ctx, &ret },
                .only_ctx => .{&ctx},
                .only_ret => .{&ret},
                .no_params => .{},
            };
            if (call_conv == .no_params) ctx.parseNone() catch return;
            invoke(func_desc, func, args, &ret);
        }
    }.@"fn";
}

fn makePhpMethod(comptime Class: type, comptime func_desc: [:0]const u8, comptime func: anytype) PhpFn {
    const kind, const call_conv = comptime detectPhpMethodCallConv(Class, func);
    return struct {
        fn @"fn"(execute_data: ?*c.zend_execute_data, return_value: ?*c.zval) callconv(.c) void {
            var ctx = ExecContext.init(execute_data.?);
            var ret = Zval.from(return_value.?);
            const args = blk: {
                if (kind == .object) {
                    const obj: *Class = .from(.std, ctx.thisObject().?);
                    const receiver = if (@typeInfo(@TypeOf(func)).@"fn".params[0].type.? == @FieldType(Class, "impl")) obj.impl else &obj.impl;
                    break :blk switch (call_conv) {
                        .standard => .{ receiver, &ctx, &ret },
                        .only_ctx => .{ receiver, &ctx },
                        .only_ret => .{ receiver, &ret },
                        .no_params => .{receiver},
                    };
                }
                break :blk switch (call_conv) {
                    .standard => .{ &ctx, &ret },
                    .only_ctx => .{&ctx},
                    .only_ret => .{&ret},
                    .no_params => .{},
                };
            };
            if (call_conv == .no_params) ctx.parseNone() catch return;
            invoke(func_desc, func, args, &ret);
        }
    }.@"fn";
}

fn exportPhpFn(comptime func_kind: PhpFnKind, comptime func_name: [:0]const u8, comptime func: PhpFn) void {
    const full_name = switch (func_kind) {
        .function => "zif_" ++ func_name,
        .method => "zim_" ++ func_name,
    };
    @export(&func, .{ .name = full_name });
}

fn detectPhpFnReturnType(comptime T: type) PhpFnReturnType {
    const is_error_union = @typeInfo(T) == .error_union;
    const scalar_type: Zval.Kind = detect_return_type: switch (T) {
        void => .undef,
        bool => .bool,
        else => |t| switch (@typeInfo(t)) {
            .int => .int,
            .float => .float,
            .error_union => |error_union| continue :detect_return_type error_union.payload,
            else => @compileError("php function/method bind error: return type must be int | bool | float | void, ErrorSet is optional."),
        },
    };
    return if (is_error_union) .{ .error_union = scalar_type } else .{ .scalar = scalar_type };
}

fn detectPhpFnCallConv(comptime func: anytype) PhpFnCallConv {
    const type_info = @typeInfo(@TypeOf(func));
    if (type_info != .@"fn") @compileError("export php method/function must be a fn type");
    const fn_type_info = type_info.@"fn";

    if (fn_type_info.params.len == 2 and
        fn_type_info.params[0].type.? == *ExecContext and
        fn_type_info.params[1].type.? == *Zval) return .standard;

    if (fn_type_info.params.len == 0) return .no_params;
    if (fn_type_info.params.len == 1 and fn_type_info.params[0].type.? == *ExecContext) return .only_ctx;
    if (fn_type_info.params.len == 1 and fn_type_info.params[0].type.? == *Zval) return .only_ret;

    @compileLog(@TypeOf(func));
    @compileError(
        \\php function/method bind error: function signature must be:
        \\
        \\params:
        \\  - (ctx: *ExecContext, ret: *Zval)
        \\  - (ctx: *ExecContext)
        \\  - (ret: *Zval)
        \\  - ()
        \\returns:
        \\  - void
        \\  - int
        \\  - bool
        \\  - float
        \\  ErrorSet is optional.
    );
}

fn detectPhpMethodCallConv(comptime Class: anytype, comptime func: anytype) struct { PhpMethodKind, PhpFnCallConv } {
    const type_info = @typeInfo(@TypeOf(func));
    if (type_info != .@"fn") @compileError("export php method/function must be a fn type");
    const fn_type_info = type_info.@"fn";

    const offset: comptime_int, const fn_kind = blk: {
        if (fn_type_info.params.len > 0) {
            const ImplType = @FieldType(Class, "impl");
            const ReceiverType = fn_type_info.params[0].type orelse void;
            if (ReceiverType == ImplType or ReceiverType == *ImplType) {
                break :blk .{ 1, .object };
            }
            break :blk .{ 0, .static };
        }
        break :blk .{ 0, .static };
    };

    if (fn_type_info.params.len == offset + 2 and
        fn_type_info.params[offset].type.? == *ExecContext and
        fn_type_info.params[offset + 1].type.? == *Zval) return .{ fn_kind, .standard };

    if (fn_type_info.params.len == offset) return .{ fn_kind, .no_params };
    if (fn_type_info.params.len == offset + 1 and fn_type_info.params[offset].type.? == *ExecContext) return .{ fn_kind, .only_ctx };
    if (fn_type_info.params.len == offset + 1 and fn_type_info.params[offset].type.? == *Zval) return .{ fn_kind, .only_ret };

    @compileLog(fn_kind, @TypeOf(func));
    @compileError(
        \\php method bind error: method signature must be:
        \\
        \\params:
        \\  static:
        \\  - (ctx: *ExecContext, ret: *Zval)
        \\  - (ctx: *ExecContext)
        \\  - (ret: *Zval)
        \\  - ()
        \\  object:
        \\  - (self: T|*T, ctx: *ExecContext, ret: *Zval)
        \\  - (self: T|*T, ctx: *ExecContext)
        \\  - (self: T|*T, ret: *Zval)
        \\  - (self: T|*T)
        \\returns:
        \\  - void
        \\  - int
        \\  - bool
        \\  - float
        \\  ErrorSet is optional.
    );
}

fn makeMethodExportName(comptime class_name: [:0]const u8, comptime func_name: [:0]const u8) [:0]const u8 {
    comptime {
        var buffer: [class_name.len:0]u8 = undefined;
        for (class_name, 0..) |ch, i| buffer[i] = if (ch == '\\') '_' else ch;
        buffer[class_name.len] = 0;
        return std.fmt.comptimePrint("{s}_{s}", .{ buffer, func_name });
    }
}

inline fn invoke(
    comptime func_desc: [:0]const u8,
    comptime func: anytype,
    args: anytype,
    ret: *Zval,
) void {
    const fn_return_type = comptime detectPhpFnReturnType(@typeInfo(@TypeOf(func)).@"fn".return_type.?);
    switch (fn_return_type) {
        .error_union => |kind| {
            const maybe_result = @call(.auto, func, args) catch |err| {
                if (c.EG("exception") == null) {
                    c.zend_throw_error(null, "%s at %s", @errorName(err).ptr, func_desc.ptr);
                }
                return;
            };
            if (kind != .undef) {
                ret.set(kind, castResult(kind, maybe_result));
            }
        },
        .scalar => |kind| {
            const result = @call(.auto, func, args);
            if (kind != .undef) {
                ret.set(kind, castResult(kind, result));
            }
        },
    }
}

inline fn castResult(comptime kind: Zval.Kind, result: anytype) @TypeOf(result) {
    return switch (kind) {
        .int => @intCast(result),
        .float => @floatCast(result),
        else => result,
    };
}
