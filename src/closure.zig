//! Create native PHP Closure values.
const std = @import("std");

const c = @import("c.zig").c;
const functions = @import("function.zig");
const Handler = functions.Handler;
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

/// Create a Closure from a typed Zig function, optionally with a leading Ctx or
/// GuardCtx. The handler parses PHP parameters and writes non-void Zig results;
/// void/!void preserves a manually set result.
/// Uses phpz.function's error and bailout handling.
/// See createFromHandler for the closure's signature and creation constraints.
pub fn createFromFn(comptime func: anytype, destination: *Zval) void {
    const handler = functions.createHandler("{closure}()", func);
    createFromHandler(handler, destination);
}

/// Create an unbound Closure from a zif_handler without registering a PHP function.
/// Declares by-value variadic arguments and no return type; the handler parses arguments.
/// Read extra named arguments with CallFrame.extraNamedArgs(); expectArgs() rejects them.
/// The handler must remain valid for the closure's lifetime.
/// Creation may trigger a Zend bailout, which must terminate the request.
pub fn createFromHandler(handler: *const Handler, destination: *Zval) void {
    std.debug.assert(destination.is(.undef) or destination.is(.null));
    const name = String.init("{closure}", false);
    defer name.release();
    var function: c.zend_function = .{ .internal_function = std.mem.zeroes(c.zend_internal_function) };
    function.internal_function.type = c.ZEND_INTERNAL_FUNCTION;
    function.internal_function.fn_flags = c.ZEND_ACC_PUBLIC | c.ZEND_ACC_VARIADIC;
    function.internal_function.function_name = name.ptr();
    function.internal_function.arg_info = @constCast(&handler_arginfo[1]);
    function.internal_function.handler = handler;
    c.zend_create_fake_closure(destination.ptr(), &function, null, null, null);
}

test {
    std.testing.refAllDecls(@This());
}
