const std = @import("std");

const c = @import("root.zig").c;
const ExecContext = @import("ExecContext.zig");
const Zval = @import("Zval.zig");

const class = @import("class.zig");

const PhpFn = fn (?*c.zend_execute_data, ?*c.zval) callconv(.c) void;
const PhpFnKind = enum { function, method, static_method };
const PhpFnCallConv = enum { standard, no_params, only_ctx, only_ret };
const PhpFnReturnKind = enum { error_union, scalar };
const PhpFnReturnType = union(PhpFnReturnKind) { error_union: Zval.Kind, scalar: Zval.Kind };

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
        exportPhpFn(.function, func_name, makePhpFn(void, func_name, func));
    }
}

pub fn method(comptime T: type, comptime func_name: [:0]const u8, comptime func: anytype) void {
    comptime {
        const real_func_name: [:0]const u8 = blk: {
            var buffer: [T.name.len]u8 = undefined;
            for (T.name, 0..) |ch, i| buffer[i] = if (ch == '\\') '_' else ch;
            const replaced = &buffer;
            const result = std.fmt.comptimePrint("{s}_{s}", .{ replaced, func_name });
            break :blk result;
        };
        exportPhpFn(.method, real_func_name, makePhpFn(T, func_name, func));
    }
}

fn makePhpFn(comptime T: type, comptime func_name: [:0]const u8, comptime func: anytype) PhpFn {
    const fn_kind, const fn_call_conv = detectPhpFnCallConv(T, func);
    const fn_return_type = detectPhpFnReturnType(@typeInfo(@TypeOf(func)).@"fn".return_type.?);

    return struct {
        fn @"fn"(execute_data: ?*c.zend_execute_data, return_value: ?*c.zval) callconv(.c) void {
            var ctx = ExecContext.init(execute_data.?);
            var ret = Zval.from(return_value.?);
            const args = blk: {
                if (fn_kind == .method) {
                    var obj: *T = @fieldParentPtr("std", ctx.thisObject().?);
                    const receiver = if (@typeInfo(@TypeOf(func)).@"fn".params[0].type.? == @FieldType(T, "inner")) obj.inner else &obj.inner;
                    break :blk switch (fn_call_conv) {
                        .standard => .{ receiver, &ctx, &ret },
                        .no_params => .{receiver},
                        .only_ctx => .{ receiver, &ctx },
                        .only_ret => .{ receiver, &ret },
                    };
                }

                if (fn_call_conv == .no_params) ctx.parseNone() catch return;
                break :blk switch (fn_call_conv) {
                    .standard => .{ &ctx, &ret },
                    .no_params => .{},
                    .only_ctx => .{&ctx},
                    .only_ret => .{&ret},
                };
            };
            switch (fn_return_type) {
                .error_union => |error_union| switch (error_union) {
                    .undef => {
                        @call(.auto, func, args) catch |err| {
                            if (c.EG("exception") != null) return;
                            if (T == void) {
                                c.zend_throw_error(null, "%s at %s()", @errorName(err).ptr, func_name.ptr);
                            } else {
                                c.zend_throw_error(null, "%s at %s::%s()", @errorName(err).ptr, T.name.ptr, func_name.ptr);
                            }
                            return;
                        };
                    },
                    else => |kind| {
                        const result = @call(.auto, func, args) catch |err| {
                            if (c.EG("exception") != null) return;
                            if (T == void) {
                                c.zend_throw_error(null, "%s at %s()", @errorName(err).ptr, func_name.ptr);
                            } else {
                                c.zend_throw_error(null, "%s at %s::%s()", @errorName(err).ptr, T.name.ptr, func_name.ptr);
                            }
                            return;
                        };
                        ret.set(kind, switch (kind) {
                            .int => @intCast(result),
                            .float => @floatCast(result),
                            else => result,
                        });
                    },
                },
                .scalar => |scalar| switch (scalar) {
                    .undef => {
                        @call(.auto, func, args);
                    },
                    else => |kind| {
                        const result = @call(.auto, func, args);
                        ret.set(kind, switch (kind) {
                            .int => @intCast(result),
                            .float => @floatCast(result),
                            else => result,
                        });
                    },
                },
            }
        }
    }.@"fn";
}

fn exportPhpFn(comptime ft: PhpFnKind, comptime func_name: [:0]const u8, comptime func: PhpFn) void {
    const full_name = switch (ft) {
        .function => "zif_" ++ func_name,
        .method, .static_method => "zim_" ++ func_name,
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

fn detectPhpFnCallConv(comptime T: type, comptime f: anytype) struct { PhpFnKind, PhpFnCallConv } {
    const type_info = @typeInfo(@TypeOf(f));
    if (type_info != .@"fn") @compileError("export php method/function must be a fn type");
    const fn_type_info = type_info.@"fn";

    const offset: comptime_int, const fn_kind = blk: {
        if (T != void and fn_type_info.params.len > 0) {
            const InnerType = @FieldType(T, "inner");
            const ReceiverType = fn_type_info.params[0].type orelse void;
            if (ReceiverType == InnerType or ReceiverType == *InnerType) {
                break :blk .{ 1, .method };
            }
            break :blk .{ 0, .static_method };
        }
        break :blk .{ 0, .function };
    };

    if (fn_type_info.params.len == offset + 2 and
        fn_type_info.params[offset].type.? == *ExecContext and
        fn_type_info.params[offset + 1].type.? == *Zval) return .{ fn_kind, .standard };

    if (fn_type_info.params.len == offset) return .{ fn_kind, .no_params };
    if (fn_type_info.params.len == offset + 1 and fn_type_info.params[offset].type.? == *ExecContext) return .{ fn_kind, .only_ctx };
    if (fn_type_info.params.len == offset + 1 and fn_type_info.params[offset].type.? == *Zval) return .{ fn_kind, .only_ret };

    @compileLog(fn_kind, @TypeOf(f));
    @compileError(
        \\php function/method bind error: function signature must be:
        \\
        \\params:
        \\  - (ctx: *ExecContext, ret: *Zval)
        \\  - (ctx: *ExecContext)
        \\  - (ret: *Zval)
        \\  - ()
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
