const std = @import("std");

pub const c = @import("c.zig").c;
pub const globals = @import("globals.zig");

pub const closure = @import("closure.zig");

pub const heap = @import("heap.zig");
pub const ini = @import("ini.zig");
pub const info = @import("info.zig");
pub const observer = @import("observer.zig");

const mod_helper = @import("module.zig");
pub const module = mod_helper.module;
pub const ModuleEntry = mod_helper.ModuleEntry;
pub const ModuleGlobals = mod_helper.ModuleGlobals;

pub const zend = @import("zend.zig");

const class_helper = @import("class.zig");
pub const Class = class_helper.Class;
pub const ClassDecl = class_helper.ClassDecl;
pub const ObjectHandlers = class_helper.ObjectHandlers;
pub const ClassEntry = zend.ClassEntry;
pub const Operator = class_helper.Operator;
pub const Comparison = class_helper.Comparison;
pub const GcBuffer = @import("gc.zig").GcBuffer;

const function_helper = @import("function.zig");
pub const function = function_helper.function;
pub const functions = function_helper.functions;
pub const namedFunctions = function_helper.namedFunctions;

pub const Ctx = @import("ctx.zig").Ctx;
pub const CallFrame = @import("ctx.zig").CallFrame;
pub const GuardCtx = @import("ctx.zig").GuardCtx;
pub const Zval = @import("zval.zig").Zval;
pub const Guard = @import("guard.zig").Guard;

pub const errors = @import("errors.zig");

pub fn printf(fmt: [:0]const u8, args: anytype) usize {
    return @call(.auto, c.php_printf, .{fmt.ptr} ++ args);
}

test {
    _ = @import("ctx.zig");
    _ = @import("class.zig");
    _ = @import("closure.zig");
    _ = @import("errors.zig");
    _ = @import("function.zig");
    _ = @import("globals.zig");
    _ = @import("gc.zig");
    _ = @import("heap.zig");
    _ = @import("guard.zig");
    _ = @import("ini.zig");
    _ = @import("info.zig");
    _ = @import("module.zig");
    _ = @import("observer.zig");
    _ = @import("stub.zig");
    _ = @import("zend.zig");
    _ = @import("zval.zig");
    _ = @import("zend/array.zig");
    _ = @import("zend/callable.zig");
    _ = @import("zend/class_entry.zig");
    _ = @import("zend/function.zig");
    _ = @import("zend/object.zig");
    _ = @import("zend/property_info.zig");
    _ = @import("zend/string.zig");
    _ = @import("zend/bailout.zig");
    _ = @import("zval/array.zig");
    _ = @import("zval/object.zig");

    std.testing.refAllDecls(@This());
}
