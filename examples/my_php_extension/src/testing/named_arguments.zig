const std = @import("std");
const phpz = @import("phpz");
const Zval = phpz.Zval;

/// PHP: checkedNamedArguments(int $name, int $age = 2, mixed ...$args): array
pub fn checkedNamedArguments(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgsAllowExtraNamed(&.{
        .{ .int = .{} },
        .{ .int = .{ .optional = true } },
    }, {});
    const result = Zval.Array.empty(ctx.ret.ptr());
    result.set(.int, "name", args[0]);
    result.set(.int, "age", args[1] orelse 2);
    try collect(ctx, result, 2);
}

/// PHP: collectArguments(int $name = 1, int $age = 2, mixed ...$args): array
pub fn collectArguments(ctx: phpz.Ctx) !void {
    try ctx.call.expectArgCount(0, std.math.maxInt(u32));
    const name = try ctx.call.expectArg(1, .{ .int = .{ .optional = true } }, {});
    const age = try ctx.call.expectArg(2, .{ .int = .{ .optional = true } }, {});
    const result = Zval.Array.empty(ctx.ret.ptr());
    result.set(.int, "name", name orelse 1);
    result.set(.int, "age", age orelse 2);
    try collect(ctx, result, 2);
}

/// Used by a generic closure and a registered by-reference variadic function.
pub fn collectAll(ctx: phpz.Ctx) !void {
    try collect(ctx, Zval.Array.empty(ctx.ret.ptr()), 0);
}

fn collect(ctx: phpz.Ctx, result: *Zval.Array, prefix: usize) !void {
    const slots = ctx.call.args();
    for (slots[@min(prefix, slots.len)..]) |*raw| {
        var copy = Zval.raw.undef;
        Zval.raw.copy(&copy, raw);
        errdefer Zval.raw.release(&copy);
        try result.append(.mixed, &copy);
    }
    if (ctx.call.extraNamedArgs()) |named| {
        var it = named.fastIterator();
        while (it.next()) |entry| {
            var copy = Zval.raw.undef;
            Zval.raw.copy(&copy, entry.value);
            result.set(.mixed, entry.key.string, &copy);
        }
    }
}

pub fn parsedSum(ctx: phpz.Ctx) !void {
    var left: phpz.c.zend_long = 0;
    var right: phpz.c.zend_long = 0;
    try ctx.call.parseArgs("ll", .{ &left, &right });
    ctx.ret.set(.int, left +| right);
}

pub fn parsedVariadicCount(ctx: phpz.Ctx) !void {
    var args: ?*phpz.c.zval = null;
    var count: u32 = 0;
    try ctx.call.parseArgs("*", .{ &args, &count });
    ctx.ret.set(.int, count);
}

/// Exercise named-argument call wrappers with zero or one positional argument.
pub fn invokeArguments(ctx: phpz.Ctx) !void {
    var callback: phpz.zend.Callable = .nil;
    const args = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
        .{ .callable = .{ .resolve = true } },
        .{ .array = .{} },
        .{ .array = .{ .nullable = true } },
        .{ .bool = .{} },
    }, .{ {}, .{ .target = &callback }, {}, {}, {} });
    defer callback.release();
    const named_params = args[3].asOptional();
    switch (args[2].len()) {
        0 => try invoke(ctx, args[0], &callback, .{}, named_params, args[4]),
        1 => try invoke(ctx, args[0], &callback, .{(args[2].findIndex(0) orelse return error.InvalidPositionalArguments).*}, named_params, args[4]),
        else => return error.TooManyTestArguments,
    }
}

fn invoke(ctx: phpz.Ctx, mode: []const u8, callback: *phpz.zend.Callable, params: anytype, named_params: ?*phpz.zend.Array, guarded: bool) !void {
    if (std.mem.eql(u8, mode, "callable-cleanup")) {
        // Native output also works after bailout has cleared the PHP execute frame.
        defer std.debug.print("Zig cleanup\n", .{});
        const result = if (guarded) callback.tryCall(null, params, named_params) else callback.call(null, params, named_params);
        result catch |err| {
            std.debug.print("Zig error: {s}\n", .{@errorName(err)});
            return err;
        };
        std.debug.print("Zig returned\n", .{});
        return;
    }
    if (std.mem.eql(u8, mode, "callable-discard")) {
        if (guarded) {
            try callback.tryCall(null, params, named_params);
            try callback.tryCall(null, params, null);
            try callback.tryCall(ctx.ret.ptr(), params, named_params);
            try callback.tryCall(null, params, null);
        } else {
            try callback.call(null, params, named_params);
            try callback.call(null, params, null);
            try callback.call(ctx.ret.ptr(), params, named_params);
            try callback.call(null, params, null);
        }
        return;
    }
    if (std.mem.eql(u8, mode, "callable")) {
        if (guarded) try callback.tryCall(ctx.ret.ptr(), params, named_params) else try callback.call(ctx.ret.ptr(), params, named_params);
        return;
    }
    const function = phpz.zend.Function.from(callback.fcc.function_handler orelse return error.FunctionNotFound);
    if (std.mem.eql(u8, mode, "function")) {
        if (guarded) try function.tryCall(ctx.ret.ptr(), params, named_params) else try function.call(ctx.ret.ptr(), params, named_params);
    } else if (std.mem.eql(u8, mode, "static")) {
        const scope = phpz.ClassEntry.from(callback.fcc.called_scope orelse return error.ClassNotFound);
        if (guarded) try function.tryCallStatic(scope, ctx.ret.ptr(), params, named_params) else try function.callStatic(scope, ctx.ret.ptr(), params, named_params);
    } else if (std.mem.eql(u8, mode, "object-static")) {
        // Read the receiver from the original callable array;
        // fcc.object may be null for static methods.
        const target = try Zval.raw.as(ctx.call.arg(2), .array);
        const object = try Zval.raw.as(target.findIndex(0) orelse return error.ObjectNotFound, .object);
        if (guarded) try object.tryCallStatic(function.name(), object.class(), ctx.ret.ptr(), params, named_params) else try object.callStatic(function.name(), object.class(), ctx.ret.ptr(), params, named_params);
    } else {
        const object = phpz.zend.Object.from(callback.fcc.object orelse return error.ObjectNotFound);
        if (std.mem.eql(u8, mode, "method")) {
            if (guarded) try function.tryCallMethod(object, ctx.ret.ptr(), params, named_params) else try function.callMethod(object, ctx.ret.ptr(), params, named_params);
        } else if (std.mem.eql(u8, mode, "object")) {
            if (guarded) try object.tryCall(function.name(), ctx.ret.ptr(), params, named_params) else try object.call(function.name(), ctx.ret.ptr(), params, named_params);
        } else return error.UnknownCallMode;
    }
}
