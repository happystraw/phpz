const std = @import("std");
const phpz = @import("phpz");
const named_arguments = @import("named_arguments.zig");
const Handler = @typeInfo(@typeInfo(phpz.c.zif_handler).optional.child).pointer.child;

fn sumHandler(execute_data: ?*phpz.c.zend_execute_data, return_value: ?*phpz.c.zval) callconv(@typeInfo(Handler).@"fn".attrs.@"callconv") void {
    const ctx: phpz.Ctx = .{ .call = .from(execute_data.?), .ret = .from(return_value.?) };
    const args = ctx.call.expectArgs(&.{ .{ .int = .{} }, .{ .int = .{} } }, {}) catch return;
    ctx.ret.set(.int, args[0] +| args[1]);
}

/// PHP: MyPHPExt\Test\makeHandlerClosure(): Closure
pub fn makeHandlerClosure(ctx: phpz.Ctx) !void {
    try ctx.call.expectNoArgs();
    phpz.closure.fromHandler(&sumHandler, ctx.ret);
}

fn sum(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{ .{ .int = .{} }, .{ .int = .{} } }, {});
    ctx.ret.set(.int, args[0] +| args[1]);
}

fn empty() void {}

fn fail() !void {
    return error.ExampleFailure;
}

fn value(ctx: phpz.Ctx) void {
    ctx.ret.set(.int, 42);
}

/// PHP: MyPHPExt\Test\makeFnClosure(string $kind = "sum"): Closure
pub fn makeFnClosure(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{.{ .string = .{ .optional = true } }}, {});
    const kind = args[0] orelse "sum";
    if (std.mem.eql(u8, kind, "sum")) {
        phpz.closure.fromFn(sum, ctx.ret);
    } else if (std.mem.eql(u8, kind, "empty")) {
        phpz.closure.fromFn(empty, ctx.ret);
    } else if (std.mem.eql(u8, kind, "fail")) {
        phpz.closure.fromFn(fail, ctx.ret);
    } else if (std.mem.eql(u8, kind, "value")) {
        phpz.closure.fromFn(value, ctx.ret);
    } else if (std.mem.eql(u8, kind, "guard_value")) {
        phpz.closure.fromFn(@import("guard.zig").value, ctx.ret);
    } else if (std.mem.eql(u8, kind, "named")) {
        phpz.closure.fromFn(named_arguments.collectAll, ctx.ret);
    } else if (std.mem.eql(u8, kind, "checked_named")) {
        phpz.closure.fromFn(named_arguments.checkedNamedArguments, ctx.ret);
    } else if (std.mem.eql(u8, kind, "parse")) {
        phpz.closure.fromFn(named_arguments.parsedSum, ctx.ret);
    } else if (std.mem.eql(u8, kind, "parse_variadic")) {
        phpz.closure.fromFn(named_arguments.parsedVariadicCount, ctx.ret);
    } else return error.UnknownClosureKind;
}

/// PHP: MyPHPExt\Test\wrapClosure(string $name, ?object $object = null, ?string $class = null): Closure
pub fn wrapClosure(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
        .{ .object = .{ .optional = true, .nullable = true } },
        .{ .string = .{ .optional = true, .nullable = true } },
    }, {});
    const object = if (args[1]) |arg| arg.asOptional() else null;
    const class_name = if (args[2]) |arg| arg.asOptional() else null;
    const scope = if (class_name) |name|
        phpz.ClassEntry.lookup(name, true) orelse return error.ClassNotFound
    else if (object) |obj|
        obj.class()
    else
        null;
    const function = (if (scope) |ce|
        phpz.zend.Function.findMethod(ce, args[0])
    else
        phpz.zend.Function.fetch(args[0])) orelse return error.FunctionNotFound;
    try function.toClosure(ctx.ret, .{ .object = object, .called_scope = scope });
}
