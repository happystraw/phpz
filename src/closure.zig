//! Create native PHP Closure values.
const std = @import("std");

const c = @import("c.zig").c;
const function_helper = @import("function.zig");
const Handler = function_helper.Handler;
const String = @import("zend/string.zig").String;
const Zval = @import("zval.zig").Zval;

const handler_arginfo = [_]c.zend_internal_arg_info{
    std.mem.zeroes(c.zend_internal_arg_info),
    .{
        .name = "args",
        .type = .{ .ptr = null, .type_mask = c._ZEND_IS_VARIADIC_BIT },
        .default_value = null,
    },
};

/// Create a Closure from fn(Ctx) or fn(), returning void or !void.
/// Uses phpz.function's error and bailout handling.
/// See fromHandler for the closure's signature and creation constraints.
pub fn fromFn(comptime func: anytype, result: *Zval) void {
    const handler = function_helper.wrapFn("{closure}()", func);
    fromHandler(handler, result);
}

/// Create an unbound Closure from a zif_handler without registering a PHP function.
/// Declares by-value variadic arguments and no return type; the handler parses arguments.
/// Read extra named arguments with Ctx.Call.extraNamedArgs(); expectArgs() rejects them.
/// The handler must remain valid for the closure's lifetime.
/// Creation may trigger a Zend bailout, which must terminate the request.
pub fn fromHandler(handler: *const Handler, result: *Zval) void {
    std.debug.assert(result.is(.undef) or result.is(.null));
    const name = String.init("{closure}", false);
    defer name.release();
    var function: c.zend_function = .{ .internal_function = std.mem.zeroes(c.zend_internal_function) };
    function.internal_function.type = c.ZEND_INTERNAL_FUNCTION;
    function.internal_function.fn_flags = c.ZEND_ACC_PUBLIC | c.ZEND_ACC_VARIADIC;
    function.internal_function.function_name = name.ptr();
    function.internal_function.arg_info = @constCast(&handler_arginfo[1]);
    function.internal_function.handler = handler;
    c.zend_create_fake_closure(result.ptr(), &function, null, null, null);
}

test {
    std.testing.refAllDecls(@This());
}
