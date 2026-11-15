const std = @import("std");
const phpz = @import("phpz");
const Zval = phpz.Zval;

/// PHP: checkedNamedArguments(int $name, int $age = 2, mixed ...$args): array
pub fn checkedNamedArguments(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .int = .{} },
        .{ .int = .{ .optional = true } },
        .{ .variadic = .{} },
    }, {});
    try args[2].check(.named_only);
    const result = Zval.Array.empty(ctx.retval.ptr());
    result.set(.int, "name", args[0]);
    result.set(.int, "age", args[1] orelse 2);
    try collect(args[2], result);
}

/// PHP: collectArguments(int $name = 1, int $age = 2, mixed ...$args): array
pub fn collectArguments(ctx: phpz.Ctx, name: ?i64, age: ?i64, rest: phpz.Variadic) !void {
    const result = Zval.Array.empty(ctx.retval.ptr());
    result.set(.int, "name", name orelse 1);
    result.set(.int, "age", age orelse 2);
    try collect(rest, result);
}

/// Used by a generic closure and a registered by-reference variadic function.
pub fn collectAll(ctx: phpz.Ctx, rest: phpz.Variadic) !void {
    try collect(rest, Zval.Array.empty(ctx.retval.ptr()));
}

fn collect(rest: phpz.Variadic, result: *Zval.Array) !void {
    var it = rest.iterator();
    while (it.next()) |entry| {
        const value = try entry.expect(.{ .mixed = .{} }, {});
        var copy = Zval.raw.undef;
        Zval.raw.copy(&copy, value.ptr());
        errdefer Zval.raw.release(&copy);
        if (entry.name()) |name| result.set(.mixed, name, &copy) else try result.append(.mixed, &copy);
    }
}

pub fn parsedSum(ctx: phpz.Ctx) !i64 {
    var left: phpz.c.zend_long = 0;
    var right: phpz.c.zend_long = 0;
    try ctx.call.parseArgs("ll", .{ &left, &right });
    return left +| right;
}

pub fn parsedVariadicCount(ctx: phpz.Ctx) !u32 {
    var args: ?*phpz.c.zval = null;
    var count: u32 = 0;
    try ctx.call.parseArgs("*", .{ &args, &count });
    return count;
}

/// Exercise named-argument call wrappers with zero or one positional argument.
pub fn invokeArguments(ctx: phpz.Ctx, mode: []const u8, callback: *phpz.zend.Callable, positional: *phpz.zend.Array, named: phpz.Nullable(*phpz.zend.Array), guarded: bool) !void {
    const named_params = named.asOptional();
    switch (positional.len()) {
        0 => try invoke(ctx, mode, callback, .{}, named_params, guarded),
        1 => try invoke(ctx, mode, callback, .{(positional.findIndex(0) orelse return error.InvalidPositionalArguments).*}, named_params, guarded),
        else => return error.TooManyTestArguments,
    }
}

fn invoke(ctx: phpz.Ctx, mode: []const u8, callback: *phpz.zend.Callable, params: anytype, named_params: ?*phpz.zend.Array, guarded: bool) !void {
    if (std.mem.startsWith(u8, mode, "cache")) {
        var cache = try callback.retainCache();
        defer cache.deinit();
        if (std.mem.eql(u8, mode, "cache-cleanup")) {
            defer std.debug.print("Zig cleanup\n", .{});
            const result = if (guarded) cache.tryCall(null, params, named_params) else cache.call(null, params, named_params);
            result catch |err| {
                std.debug.print("Zig error: {s}\n", .{@errorName(err)});
                return err;
            };
            std.debug.print("Zig returned\n", .{});
        } else if (std.mem.eql(u8, mode, "cache-discard")) {
            if (guarded) try cache.tryCall(null, params, named_params) else try cache.call(null, params, named_params);
        } else {
            if (guarded) try cache.tryCall(ctx.retval.ptr(), params, named_params) else try cache.call(ctx.retval.ptr(), params, named_params);
        }
        return;
    }
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
            try callback.tryCall(ctx.retval.ptr(), params, named_params);
            try callback.tryCall(null, params, null);
        } else {
            try callback.call(null, params, named_params);
            try callback.call(null, params, null);
            try callback.call(ctx.retval.ptr(), params, named_params);
            try callback.call(null, params, null);
        }
        return;
    }
    if (std.mem.eql(u8, mode, "callable")) {
        if (guarded) try callback.tryCall(ctx.retval.ptr(), params, named_params) else try callback.call(ctx.retval.ptr(), params, named_params);
        return;
    }
    const function = phpz.zend.Function.from(callback.fcc.function_handler orelse return error.FunctionNotFound);
    if (std.mem.eql(u8, mode, "function")) {
        if (guarded) try function.tryCall(ctx.retval.ptr(), params, named_params) else try function.call(ctx.retval.ptr(), params, named_params);
    } else if (std.mem.eql(u8, mode, "static")) {
        const scope = phpz.ClassEntry.from(callback.fcc.called_scope orelse return error.ClassNotFound);
        if (guarded) try function.tryCallStatic(scope, ctx.retval.ptr(), params, named_params) else try function.callStatic(scope, ctx.retval.ptr(), params, named_params);
    } else if (std.mem.eql(u8, mode, "class-static")) {
        const scope = phpz.ClassEntry.from(callback.fcc.called_scope orelse return error.ClassNotFound);
        if (guarded) try scope.tryCallStatic(function.name(), ctx.retval.ptr(), params, named_params) else try scope.callStatic(function.name(), ctx.retval.ptr(), params, named_params);
    } else {
        const object = phpz.zend.Object.from(callback.fcc.object orelse return error.ObjectNotFound);
        if (std.mem.eql(u8, mode, "method")) {
            if (guarded) try function.tryCallMethod(object, ctx.retval.ptr(), params, named_params) else try function.callMethod(object, ctx.retval.ptr(), params, named_params);
        } else if (std.mem.eql(u8, mode, "object")) {
            if (guarded) try object.tryCall(function.name(), ctx.retval.ptr(), params, named_params) else try object.call(function.name(), ctx.retval.ptr(), params, named_params);
        } else return error.UnknownCallMode;
    }
}
