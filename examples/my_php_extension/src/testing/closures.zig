const std = @import("std");
const phpz = @import("phpz");
const named_arguments = @import("named_arguments.zig");
const Handler = @typeInfo(@typeInfo(phpz.c.zif_handler).optional.child).pointer.child;

fn sumHandler(execute_data: ?*phpz.c.zend_execute_data, return_value: ?*phpz.c.zval) callconv(@typeInfo(Handler).@"fn".attrs.@"callconv") void {
    const ctx: phpz.Ctx = .{ .call = .from(execute_data.?), .retval = .from(return_value.?) };
    const args = ctx.call.expectArgs(&.{ .{ .int = .{} }, .{ .int = .{} } }, {}) catch return;
    ctx.retval.set(.int, args[0] +| args[1]);
}

/// PHP: MyPHPExt\Test\makeHandlerClosure(): Closure
pub fn makeHandlerClosure(ctx: phpz.Ctx) !void {
    try ctx.call.expectNoArgs();
    phpz.closure.createFromHandler(&sumHandler, ctx.retval);
}

fn sum(left: i64, right: i64) i64 {
    return left +| right;
}

fn empty() void {}

fn fail() !void {
    return error.ExampleFailure;
}

fn value() i64 {
    return 42;
}

fn narrow(number: u8) u8 {
    return number;
}

fn withContext(ctx: phpz.Ctx, number: i64) i64 {
    _ = ctx;
    return number + 1;
}

fn nullableString(value_arg: ?phpz.Nullable(*phpz.zend.String)) []const u8 {
    if (value_arg) |value_present| return switch (value_present) {
        .null => "null",
        .value => |str| str.slice(),
    };
    return "omitted";
}

fn optionalCallable(callback: ?phpz.Nullable(*phpz.zend.Callable)) ![]const u8 {
    if (callback) |present| {
        switch (present) {
            .null => return "null",
            .value => |resolved| {
                try resolved.tryCall(null, .{}, null);
                return "called";
            },
        }
    }
    return "omitted";
}

fn echoBytes(bytes: []const u8) []const u8 {
    return bytes;
}

fn ownedString() *phpz.zend.String {
    return phpz.zend.String.init("owned", false);
}

fn borrowedString(str: *phpz.zend.String) *phpz.zend.String {
    return str.copy();
}

fn arrayLength(values: *phpz.zend.Array) usize {
    return values.len();
}

fn newArray() *phpz.zend.Array {
    return phpz.zend.Array.empty();
}

fn sharedArray(values: *phpz.zend.Array) *phpz.zend.Array {
    if (!values.isImmutable()) values.addref();
    return values;
}

fn copyMixed(value_arg: *phpz.Zval) *phpz.Zval {
    return value_arg;
}

fn maybe(value_arg: bool) ?i64 {
    return if (value_arg) 42 else null;
}

fn narrowFloat(value_arg: f32) f32 {
    return value_arg;
}

fn tooLarge() u64 {
    return std.math.maxInt(u64);
}

const MixedValue = phpz.Mixed(&.{ .null, .int, .float, .bool, .string, .array, .object, .resource });

fn mixed(input: MixedValue) MixedValue {
    switch (input) {
        .array => |array| if (!array.isImmutable()) array.addref(),
        inline .object, .resource => |pointer| pointer.addref(),
        else => {},
    }
    return input;
}

fn optionalMixed(input: ?phpz.Mixed(&.{ .null, .int, .string })) []const u8 {
    return if (input) |present| @tagName(present) else "omitted";
}

/// PHP: MyPHPExt\Test\makeFnClosure(string $kind = "sum"): Closure
pub fn makeFnClosure(ctx: phpz.Ctx, kind_arg: ?[]const u8) !void {
    const kind = kind_arg orelse "sum";
    if (std.mem.eql(u8, kind, "sum")) {
        phpz.closure.createFromFn(sum, ctx.retval);
    } else if (std.mem.eql(u8, kind, "empty")) {
        phpz.closure.createFromFn(empty, ctx.retval);
    } else if (std.mem.eql(u8, kind, "fail")) {
        phpz.closure.createFromFn(fail, ctx.retval);
    } else if (std.mem.eql(u8, kind, "value")) {
        phpz.closure.createFromFn(value, ctx.retval);
    } else if (std.mem.eql(u8, kind, "narrow")) {
        phpz.closure.createFromFn(narrow, ctx.retval);
    } else if (std.mem.eql(u8, kind, "with_context")) {
        phpz.closure.createFromFn(withContext, ctx.retval);
    } else if (std.mem.eql(u8, kind, "nullable_string")) {
        phpz.closure.createFromFn(nullableString, ctx.retval);
    } else if (std.mem.eql(u8, kind, "optional_callable")) {
        phpz.closure.createFromFn(optionalCallable, ctx.retval);
    } else if (std.mem.eql(u8, kind, "echo_bytes")) {
        phpz.closure.createFromFn(echoBytes, ctx.retval);
    } else if (std.mem.eql(u8, kind, "owned_string")) {
        phpz.closure.createFromFn(ownedString, ctx.retval);
    } else if (std.mem.eql(u8, kind, "borrowed_string")) {
        phpz.closure.createFromFn(borrowedString, ctx.retval);
    } else if (std.mem.eql(u8, kind, "array_length")) {
        phpz.closure.createFromFn(arrayLength, ctx.retval);
    } else if (std.mem.eql(u8, kind, "new_array")) {
        phpz.closure.createFromFn(newArray, ctx.retval);
    } else if (std.mem.eql(u8, kind, "shared_array")) {
        phpz.closure.createFromFn(sharedArray, ctx.retval);
    } else if (std.mem.eql(u8, kind, "copy_mixed")) {
        phpz.closure.createFromFn(copyMixed, ctx.retval);
    } else if (std.mem.eql(u8, kind, "maybe")) {
        phpz.closure.createFromFn(maybe, ctx.retval);
    } else if (std.mem.eql(u8, kind, "narrow_float")) {
        phpz.closure.createFromFn(narrowFloat, ctx.retval);
    } else if (std.mem.eql(u8, kind, "too_large")) {
        phpz.closure.createFromFn(tooLarge, ctx.retval);
    } else if (std.mem.eql(u8, kind, "mixed")) {
        phpz.closure.createFromFn(mixed, ctx.retval);
    } else if (std.mem.eql(u8, kind, "optional_mixed")) {
        phpz.closure.createFromFn(optionalMixed, ctx.retval);
    } else if (std.mem.eql(u8, kind, "guard_value")) {
        phpz.closure.createFromFn(@import("guard.zig").value, ctx.retval);
    } else if (std.mem.eql(u8, kind, "named")) {
        phpz.closure.createFromFn(named_arguments.collectAll, ctx.retval);
    } else if (std.mem.eql(u8, kind, "checked_named")) {
        phpz.closure.createFromFn(named_arguments.checkedNamedArguments, ctx.retval);
    } else if (std.mem.eql(u8, kind, "parse")) {
        phpz.closure.createFromFn(named_arguments.parsedSum, ctx.retval);
    } else if (std.mem.eql(u8, kind, "parse_variadic")) {
        phpz.closure.createFromFn(named_arguments.parsedVariadicCount, ctx.retval);
    } else return error.UnknownClosureKind;
}

/// PHP: MyPHPExt\Test\wrapClosure(string $name, ?object $object = null, ?string $class = null): Closure
pub fn wrapClosure(ctx: phpz.Ctx, function_name: []const u8, object_arg: ?phpz.Nullable(*phpz.zend.Object), class_arg: ?phpz.Nullable([]const u8)) !void {
    const object = if (object_arg) |arg| arg.asOptional() else null;
    const class_name = if (class_arg) |arg| arg.asOptional() else null;
    const scope = if (class_name) |name|
        (try phpz.ClassEntry.lookup(name, true)) orelse return error.ClassNotFound
    else if (object) |obj|
        obj.class()
    else
        null;
    const function = (if (scope) |ce|
        phpz.zend.Function.findMethod(ce, function_name)
    else
        phpz.zend.Function.fetch(function_name)) orelse return error.FunctionNotFound;
    try function.createClosure(ctx.retval, .{ .object = object, .called_scope = scope });
}
