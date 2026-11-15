//! Create native PHP Closure values.
const std = @import("std");

const c = @import("c.zig").c;
const functions = @import("function.zig");
const Handler = functions.Handler;
const Function = @import("zend/function.zig").Function;
const String = @import("zend/string.zig").String;
const Zval = @import("zval.zig").Zval;

/// Shared argument metadata borrowed by native closures.
pub const handler_arginfo = struct {
    const needs_conversion = c.PHP_VERSION_ID >= 80600;
    const Info = if (needs_conversion) c.zend_arg_info else c.zend_internal_arg_info;
    const declaration = blk: {
        var info = std.mem.zeroes([2]c.zend_internal_arg_info);
        info[1].name = "args";
        info[1].type.type_mask = c._ZEND_IS_VARIADIC_BIT;
        break :blk info;
    };
    var runtime: if (needs_conversion) [declaration.len]Info else void = undefined;

    /// Prepare PHP 8.6 runtime arginfo once during MINIT.
    pub fn init() void {
        if (comptime needs_conversion) {
            for (&runtime, &declaration, 0..) |*target, *source, i| {
                c.zend_convert_internal_arg_info(target, source, i == 0, true);
            }
        }
    }

    pub inline fn ptr() *const Info {
        return if (comptime needs_conversion) &runtime[1] else &declaration[1];
    }
};

/// Identify closures created by createFromHandler or createFromFn.
pub fn isPhpzClosure(function: *Function) bool {
    return function.kind() == .internal and
        function.ptr().internal_function.arg_info == handler_arginfo.ptr();
}

/// Create a Closure from a typed Zig function, optionally with a leading Ctx or
/// GuardCtx. The handler parses PHP parameters and writes non-void Zig results;
/// void/!void preserves a manually set result.
/// A final Variadic parameter collects positional and extra named arguments.
/// Uses phpz.function's error and bailout handling.
/// See createFromHandler for the closure's signature and creation constraints.
pub fn createFromFn(comptime func: anytype, destination: *Zval) void {
    const handler = functions.createHandler("{closure}()", func);
    createFromHandler(handler, destination);
}

/// Create an unbound Closure from a zif_handler without registering a PHP function.
/// Declares by-value variadic arguments and no return type; the handler parses arguments.
/// Read extra named arguments with CallFrame.extraNamedArgs() or a final
/// .variadic expectArgs() spec. expectArgs() otherwise rejects them.
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
    function.internal_function.arg_info = @constCast(handler_arginfo.ptr());
    function.internal_function.handler = handler;
    c.zend_create_fake_closure(destination.ptr(), &function, null, null, null);
}

test {
    std.testing.refAllDecls(@This());
}
