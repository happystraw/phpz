const std = @import("std");

pub const c = @import("c.zig").c;

pub const heap = @import("heap.zig");

const mod_helper = @import("module.zig");
pub const module = mod_helper.module;
pub const ModuleEntry = mod_helper.ModuleEntry;

const class_helper = @import("class.zig");
pub const Class = class_helper.Class;
pub const ClassEntry = class_helper.ClassEntry;

const function_helper = @import("function.zig");
pub const function = function_helper.function;
pub const method = function_helper.method;

pub const ExecContext = @import("ExecContext.zig");
pub const Zval = @import("Zval.zig");
pub const zend = @import("zend.zig");

pub fn resolveCircularTypes() void {
    comptime {
        // NOTE: Circular type dependency exists in PHP C headers:
        //   zif_handler -> zval -> zend_value -> zend_function -> zend_internal_function -> zif_handler
        // This is a temporary workaround: create function signatures using these types in a comptime block
        // to force the compiler to resolve them early
        // See: https://github.com/ziglang/zig/issues/12325
        _ = ?*const fn (execute_data: [*c]c.zend_execute_data, return_value: [*c]c.zval) callconv(.c) void;
    }
}

pub fn printf(fmt: [:0]const u8, args: anytype) usize {
    return @call(.auto, c.php_printf, .{fmt.ptr} ++ args);
}

/// Alternative to `zend_string_init` function, primarily used as a replacement
/// for zend_string_init in *_arginfo.h files.
/// Uses direct allocation to avoid the translate-c generated `zend_string_init`
/// function (which can cause index out of bounds errors).
pub export fn zig_zend_string_init(str: [*]const u8, len: usize, persistent: bool) *c.zend_string {
    // See: https://codeberg.org/ziglang/translate-c/issues/277
    // See: https://codeberg.org/ziglang/translate-c/issues/79
    const result_str = c.zend_string_alloc(len, persistent);
    @memcpy(@as([*]u8, @ptrCast(&result_str.*.val))[0..len], str[0..]);
    @as([*]u8, @ptrCast(&result_str.*.val))[len] = 0;
    return @ptrCast(result_str);
}
