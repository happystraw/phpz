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
};

test {
    std.testing.refAllDecls(FunctionEntry);
}
