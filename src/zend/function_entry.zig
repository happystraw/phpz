const std = @import("std");

const c = @import("../root.zig").c;

pub const FunctionEntry = opaque {
    pub inline fn from(entry: *const c.zend_function_entry) *const FunctionEntry {
        return @ptrCast(entry);
    }

    pub inline fn ptr(self: *const FunctionEntry) *const c.zend_function_entry {
        return @ptrCast(@alignCast(self));
    }

    pub inline fn name(self: *const FunctionEntry) ?[:0]const u8 {
        const fname = self.ptr().fname;
        if (fname == null) return null;
        return std.mem.span(fname);
    }

    pub inline fn handler(self: *const FunctionEntry) c.zif_handler {
        return self.ptr().handler;
    }

    pub inline fn flags(self: *const FunctionEntry) u32 {
        return self.ptr().flags;
    }

    pub inline fn isAbstract(self: *const FunctionEntry) bool {
        return (self.flags() & @as(u32, @intCast(c.ZEND_ACC_ABSTRACT))) != 0;
    }

    pub inline fn isStatic(self: *const FunctionEntry) bool {
        return (self.flags() & @as(u32, @intCast(c.ZEND_ACC_STATIC))) != 0;
    }

    pub inline fn isSentinel(self: *const FunctionEntry) bool {
        return self.ptr().fname == null;
    }

    /// Whether Zend registers the entry as variadic, judging by its last arginfo
    /// slot like zend_register_functions(). Only variadic functions can receive
    /// extra named arguments; Zend rejects unknown names for all others.
    pub inline fn isVariadic(self: *const FunctionEntry) bool {
        const entry = self.ptr();
        if (entry.arg_info == null) return false;
        const variadic_bit: u32 = @intCast(c._ZEND_IS_VARIADIC_BIT);
        return (entry.arg_info[entry.num_args].type.type_mask & variadic_bit) != 0;
    }
};

test {
    std.testing.refAllDecls(FunctionEntry);
}
