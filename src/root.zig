const std = @import("std");

pub const c = @import("php_ext");

pub const mem = @import("mem.zig");

const mod = @import("module.zig");
pub const module = mod.module;
pub const ModuleEntry = mod.ModuleEntry;

const class = @import("class.zig");
pub const Class = class.Class;
pub const ClassEntry = class.ClassEntry;

pub const function = @import("function.zig").function;
pub const ExecContext = @import("ExecContext.zig");
pub const zend = @import("zend.zig");
pub const Zval = @import("Zval.zig");

pub fn forceTypeResolution() void {
    comptime {
        // PHP C 头文件中存在循环类型依赖：
        // zif_handler -> zval -> zend_value -> zend_function -> zend_internal_function -> zif_handler
        //
        // 这是一个临时的解决方案：在 comptime 块中创建使用这些类型的函数签名，强制编译器提前解析它们
        // See: https://github.com/ziglang/zig/issues/12325
        _ = ?*const fn (execute_data: [*c]c.zend_execute_data, return_value: [*c]c.zval) callconv(.c) void;
    }
}

pub fn printf(fmt: [:0]const u8, args: anytype) usize {
    return @call(.auto, c.php_printf, .{fmt.ptr} ++ args);
}
