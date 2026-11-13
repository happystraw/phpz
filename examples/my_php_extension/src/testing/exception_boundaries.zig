const std = @import("std");
const phpz = @import("phpz");
const c = phpz.c;

/// PHP: MyPHPExt\Test\checkExceptionBoundary(string $api, mixed $value): void
pub fn checkExceptionBoundary(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{ .{ .string = .{} }, .{ .mixed = .{} } }, {});
    const api = args[0];
    const value = args[1];
    defer std.debug.print("Zig cleanup\n", .{});
    invoke(ctx.call, api, value) catch |err| {
        // Observe the actual Zig result without consuming PHP's control signal.
        std.debug.print("Zig error: {s}; pending={any}\n", .{ @errorName(err), phpz.exception.hasPending() });
        return err;
    };
    std.debug.print("Zig returned\n", .{});
}

fn invoke(frame: *phpz.CallFrame, api: []const u8, value: *phpz.Zval) !void {
    if (std.mem.eql(u8, api, "oom-handled")) {
        var callback: phpz.zend.Callable = .nil;
        try callback.parse(value.ptr(), null);
        const allocator = phpz.heap.php_allocator;
        const block = allocator.alloc(u8, 64 * 1024 * 1024) catch |err| {
            // Reentering PHP during cleanup handles the queued OOM before the
            // original allocation error reaches this handler's boundary.
            try std.testing.expectError(error.UnwindExit, callback.call(null, .{}, null));
            return err;
        };
        allocator.free(block);
        return error.ExpectedOutOfMemory;
    }
    if (std.mem.startsWith(u8, api, "helper-")) {
        if (value.is(.bool) and try value.as(.bool)) {
            exitSignal();
        } else if (value.is(.string)) {
            _ = phpz.exception.throwExceptionObject(.internal("Exception"), "original", 0);
        }
        return invokeHelper(api["helper-".len..]);
    }
    if (std.mem.eql(u8, api, "argument-string")) {
        _ = try frame.expectArg(2, .{ .string = .{} }, {});
        return;
    }
    if (std.mem.startsWith(u8, api, "stream") or std.mem.startsWith(u8, api, "argument-stream")) {
        if (std.mem.endsWith(u8, api, "-exit")) exitSignal();
        if (std.mem.startsWith(u8, api, "argument-")) {
            _ = try frame.expectArg(2, .{ .resource = .{ .as = .stream } }, {});
        } else {
            _ = try phpz.Stream.fromResource(try value.as(.resource));
        }
        return;
    }
    if (std.mem.eql(u8, api, "none")) return phpz.exception.check();
    if (std.mem.eql(u8, api, "eval")) return phpz.eval(try value.as(.string), null, "exit test");
    if (std.mem.eql(u8, api, "tryEval")) return phpz.tryEval(try value.as(.string), null, "exit test");
    if (std.mem.eql(u8, api, "callable") or std.mem.eql(u8, api, "function")) {
        var callable: phpz.zend.Callable = .nil;
        try callable.parse(value.ptr(), null);
        if (std.mem.eql(u8, api, "callable")) return callable.tryCall(null, .{}, null);
        return phpz.zend.Function.from(callable.fcc.function_handler.?).tryCall(null, .{}, null);
    }
    if (std.mem.eql(u8, api, "lookup")) {
        _ = try phpz.ClassEntry.lookup(try value.as(.string), true);
    } else if (std.mem.eql(u8, api, "constant")) {
        _ = try phpz.zend.Constant.get(try value.as(.string), null, false);
    } else if (std.mem.eql(u8, api, "init") or std.mem.eql(u8, api, "new") or std.mem.eql(u8, api, "new-direct")) {
        const ce = (try phpz.ClassEntry.lookup(try value.as(.string), false)).?;
        const object = if (std.mem.eql(u8, api, "init"))
            try phpz.zend.Object.init(ce)
        else if (std.mem.eql(u8, api, "new-direct"))
            try phpz.zend.Object.new(ce, .{}, null)
        else
            try phpz.zend.Object.tryNew(ce, .{}, null);
        object.release();
    } else if (std.mem.eql(u8, api, "classConstant") or std.mem.eql(u8, api, "staticProperty")) {
        const ce = (try phpz.ClassEntry.lookup(try value.as(.string), false)).?;
        if (std.mem.eql(u8, api, "classConstant")) _ = try ce.constant("VALUE", false) else _ = try ce.staticProperty("value", false);
    } else if (std.mem.eql(u8, api, "clone")) {
        const object = try (try value.as(.object)).clone();
        object.release();
    } else if (std.mem.eql(u8, api, "get")) {
        var scratch = phpz.Zval.raw.undef;
        defer phpz.Zval.raw.release(&scratch);
        _ = try (try value.as(.object)).readProperty("value", .read, &scratch);
    } else if (std.mem.eql(u8, api, "set")) {
        var input = phpz.Zval.raw.init(.int, 1);
        try (try value.as(.object)).setProperty(.mixed, "value", &input);
    } else if (std.mem.eql(u8, api, "zvalSet")) {
        var input = phpz.Zval.raw.init(.int, 1);
        try (try value.object()).set(.mixed, "value", &input);
    } else if (std.mem.eql(u8, api, "dimension")) {
        var scratch = phpz.Zval.raw.undef;
        defer phpz.Zval.raw.release(&scratch);
        var key = phpz.Zval.raw.init(.int, 0);
        _ = try (try value.as(.object)).readDimension(&key, .read, &scratch);
    } else if (std.mem.eql(u8, api, "cast")) {
        const string = try value.cast(.str);
        string.release();
    } else if (std.mem.eql(u8, api, "convert")) {
        var copy = phpz.Zval.raw.undef;
        phpz.Zval.raw.copy(&copy, value.ptr());
        defer phpz.Zval.raw.release(&copy);
        _ = try phpz.Zval.raw.convert(&copy, .str);
    } else if (std.mem.startsWith(u8, api, "throw")) {
        // Zend must preserve an already pending exit when another exception is thrown.
        exitSignal();
        const ce = phpz.ClassEntry.internal("Exception");
        if (std.mem.eql(u8, api, "throw")) return phpz.exception.throwException(ce, "preserve exit", 0);
        return phpz.exception.throwExceptionEx(ce, 0, "%s", .{@as([*:0]const u8, "preserve exit")});
    } else {
        const array = phpz.zend.Array.empty();
        defer array.release();
        var item = phpz.Zval.raw.init(.int, 1);
        _ = array.append(&item);
        _ = array.append(&item);
        if (std.mem.eql(u8, api, "apply")) return array.apply(Callbacks.apply);
        if (std.mem.eql(u8, api, "reverseApply")) return array.reverseApply(Callbacks.apply);
        if (std.mem.eql(u8, api, "applyWithArg")) {
            var arg: u8 = 0;
            return array.applyWithArg(u8, Callbacks.applyArg, &arg);
        }
        if (std.mem.eql(u8, api, "sort")) return array.sort(Callbacks.sort, true);
        if (std.mem.eql(u8, api, "compare")) {
            const other = array.dupe();
            defer other.release();
            _ = try array.compare(other, Callbacks.compare, true);
            return;
        }
        return error.UnknownBoundary;
    }
}

fn invokeHelper(api: []const u8) !void {
    const ex = phpz.exception;
    if (std.mem.eql(u8, api, "type")) return ex.typeError("fixture", .{});
    if (std.mem.eql(u8, api, "argument-type")) return ex.argumentTypeError(2, "fixture", .{});
    if (std.mem.eql(u8, api, "argument-value")) return ex.argumentValueError(2, "fixture", .{});
    if (std.mem.eql(u8, api, "argument-count")) return ex.argumentCountError("fixture", .{});
    if (std.mem.eql(u8, api, "extra-named")) return ex.unexpectedExtraNamedArgs();
    if (std.mem.eql(u8, api, "wrong-count")) return ex.wrongParameterCount(0, 0);
    if (std.mem.eql(u8, api, "none")) return ex.wrongParametersNone();
    if (std.mem.eql(u8, api, "error")) return ex.throwError(null, "fixture", .{});
    return error.UnknownHelper;
}

fn exitSignal() void {
    if (!phpz.exception.hasPending()) {
        c.zend_throw_unwind_exit();
        phpz.globals.executor().ptr().exit_status = 23;
    }
}

const Callbacks = struct {
    fn apply(_: *c.zval) phpz.zend.Array.ApplyResult {
        exitSignal();
        return .stop;
    }
    fn applyArg(_: *c.zval, _: *u8) phpz.zend.Array.ApplyResult {
        return apply(undefined);
    }
    fn compare(_: *const c.zval, _: *const c.zval) c_int {
        exitSignal();
        return 0;
    }
    fn sort(_: *c.Bucket, _: *c.Bucket) phpz.zend.Array.SortOrder {
        exitSignal();
        return .equal;
    }
};
