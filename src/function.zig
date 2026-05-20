const std = @import("std");

const c = @import("root.zig").c;
const errors = @import("errors.zig");
const Ctx = @import("Ctx.zig");

const Fn = fn (?*c.zend_execute_data, ?*c.zval) callconv(.c) void;

/// Register a Zig function as a PHP function.
///
/// This function creates a PHP function binding at compile time, allowing Zig code
/// to be called from PHP. The function signature is automatically analyzed and
/// adapted to match PHP's calling convention.
///
/// Supported function signatures:
///   - `fn (Ctx) void|!void` - Access parameters and set return value via ctx
///   - `fn () void|!void`     - No parameters or return value
///
/// When the function takes no parameters, PHP will reject calls with extra arguments.
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
/// fn add(ctx: Ctx) !void {
///     var a: i64 = undefined;
///     var b: i64 = undefined;
///     try ctx.call.parse("ll", .{ &a, &b });
///     ctx.ret.set(.int, a + b);
/// }
///
/// fn greet(ctx: Ctx) !void {
///     var name: []u8 = undefined;
///     try ctx.call.parse("s", .{ &name.ptr, &name.len });
///     const greeting = try std.fmt.allocPrint(allocator, "Hello, {s}!", .{name});
///     defer allocator.free(greeting);
///     ctx.ret.set(.string, greeting);
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
        exportFn(
            .function,
            fnEntryName(func_name),
            wrapFn(func_name ++ "()", func),
        );
    }
}

/// Register a Zig function as a PHP class method.
///
/// Similar to `function`, but exports with `zim_` prefix instead of `zif_`.
/// Use `methodWithClass` if you need automatic static/object method detection.
pub fn method(comptime class_name: [:0]const u8, comptime func_name: [:0]const u8, comptime func: anytype) void {
    comptime {
        exportFn(
            .method,
            methodEntryName(class_name, func_name),
            wrapFn(class_name ++ "::" ++ func_name ++ "()", func),
        );
    }
}

/// Register a Zig function as a PHP class method with Class type.
///
/// Accepts a Class type (returned by `class.Class()`) which enables automatic
/// detection of static vs object methods based on the function signature.
pub fn methodWithClass(comptime Class: anytype, comptime func_name: [:0]const u8, comptime func: anytype) void {
    comptime {
        exportFn(
            .method,
            methodEntryName(Class.name, func_name),
            wrapMethod(Class, Class.name ++ "::" ++ func_name ++ "()", func),
        );
    }
}

fn wrapFn(comptime func_desc: [:0]const u8, comptime func: anytype) Fn {
    const Args = std.meta.ArgsTuple(@TypeOf(func));
    return struct {
        fn @"fn"(execute_data: ?*c.zend_execute_data, return_value: ?*c.zval) callconv(.c) void {
            var ctx: Ctx = .{ .call = .from(execute_data.?), .ret = .from(return_value.?) };
            const args = switch (Args) {
                @Tuple(&.{Ctx}) => .{ctx},
                @Tuple(&.{}) => blk: {
                    ctx.call.parseNone() catch return;
                    break :blk .{};
                },
                else => @compileError(std.fmt.comptimePrint("unsupported function signature for {s}: expected fn(Ctx) or fn()", .{func_desc})),
            };
            _ = @as(anyerror!void, @call(.auto, func, args)) catch |err| {
                if (c.executor_globals.exception == null) {
                    errors.throwError(null, "%s at %s", .{ @errorName(err).ptr, func_desc.ptr });
                }
            };
        }
    }.@"fn";
}

fn wrapMethod(comptime Class: type, comptime func_desc: [:0]const u8, comptime func: anytype) Fn {
    const Args = std.meta.ArgsTuple(@TypeOf(func));
    const args_type_info = @typeInfo(Args).@"struct";
    const impl_type = @FieldType(Class, "impl");
    const kind: enum { static, object } = comptime if (args_type_info.fields.len > 0) blk: {
        const first = args_type_info.fields[0].type;
        break :blk if (first == impl_type or first == *impl_type or first == *const impl_type) .object else .static;
    } else .static;
    const impl_offset = comptime @intFromBool(kind == .object);
    return struct {
        fn @"fn"(execute_data: ?*c.zend_execute_data, return_value: ?*c.zval) callconv(.c) void {
            var ctx: Ctx = .{ .call = .from(execute_data.?), .ret = .from(return_value.?) };
            const args: Args = (if (kind == .object) blk: {
                const obj: *Class = .from(.std, ctx.call.thisObject().?);
                break :blk if (impl_type == args_type_info.fields[0].type) .{obj.impl} else .{&obj.impl};
            } else .{}) ++ rest: {
                const rest_count = args_type_info.fields.len - impl_offset;
                break :rest if (rest_count == 1)
                    if (comptime args_type_info.fields[impl_offset].type == Ctx)
                        .{ctx}
                    else
                        @compileError(std.fmt.comptimePrint("unsupported method signature for {s}: expected Ctx", .{func_desc}))
                else if (rest_count == 0) blk: {
                    ctx.call.parseNone() catch return;
                    break :blk .{};
                } else {
                    @compileError(std.fmt.comptimePrint("unsupported method signature for {s}: {any}", .{ func_desc, Args }));
                };
            };
            _ = @as(anyerror!void, @call(.auto, func, args)) catch |err| {
                if (c.executor_globals.exception == null) {
                    errors.throwError(null, "%s at %s", .{ @errorName(err).ptr, func_desc.ptr });
                }
            };
        }
    }.@"fn";
}

fn exportFn(comptime kind: enum { function, method }, comptime func_name: [:0]const u8, comptime func: Fn) void {
    const prefix = if (kind == .function) "zif_" else "zim_";
    @export(&func, .{ .name = prefix ++ func_name });
}

fn fnEntryName(comptime func_name: [:0]const u8) [:0]const u8 {
    comptime {
        var buffer: [func_name.len:0]u8 = undefined;
        for (func_name, 0..) |ch, i| buffer[i] = if (ch == '\\') '_' else ch;
        return &buffer;
    }
}

fn methodEntryName(comptime class_name: [:0]const u8, comptime func_name: [:0]const u8) [:0]const u8 {
    comptime {
        var buffer: [class_name.len]u8 = undefined;
        for (class_name, 0..) |ch, i| buffer[i] = if (ch == '\\') '_' else ch;
        return &buffer ++ "_" ++ func_name;
    }
}

test {
    std.testing.refAllDecls(@This());
}
