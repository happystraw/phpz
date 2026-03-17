const std = @import("std");

pub const c = @import("c.zig").c;

pub const heap = @import("heap.zig");

const mod_helper = @import("module.zig");
pub const module = mod_helper.module;
pub const ModuleEntry = mod_helper.ModuleEntry;

const class_helper = @import("class.zig");
pub const Class = class_helper.Class;
pub const DerivedClass = class_helper.DerivedClass;
pub const ClassEntry = class_helper.ClassEntry;

const function_helper = @import("function.zig");
pub const function = function_helper.function;
pub const method = function_helper.method;

pub const CallFrame = @import("call_frame.zig").CallFrame;
pub const Zval = @import("zval.zig").Zval;
pub const zend = @import("zend.zig");
pub const errors = @import("errors.zig");

pub fn printf(fmt: [:0]const u8, args: anytype) usize {
    return @call(.auto, c.php_printf, .{fmt.ptr} ++ args);
}
