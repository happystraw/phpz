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

    /// Whether this declaration requires frameless handlers (PHP 8.4+).
    pub inline fn isFrameless(self: *const FunctionEntry) bool {
        if (comptime @hasField(c.zend_function_entry, "frameless_function_infos")) {
            return self.ptr().frameless_function_infos != null;
        }
        return false;
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

    /// Number of required parameters.
    pub inline fn requiredParamCount(self: *const FunctionEntry) u32 {
        // The return info stores the required count in its name slot.
        return @intCast(@intFromPtr(self.ptr().arg_info[0].name));
    }

    /// Number of parameters, excluding a variadic one.
    pub inline fn fixedParamCount(self: *const FunctionEntry) u32 {
        return self.ptr().num_args - @intFromBool(self.isVariadic());
    }

    /// Whether the last parameter is variadic.
    pub inline fn isVariadic(self: *const FunctionEntry) bool {
        const entry = self.ptr();
        return entry.num_args != 0 and (entry.arg_info[entry.num_args].type.type_mask & c._ZEND_IS_VARIADIC_BIT) != 0;
    }

    /// Whether the function returns by reference.
    pub inline fn returnsReference(self: *const FunctionEntry) bool {
        return sendMode(self.ptr().arg_info[0]) != 0;
    }

    /// Name of the parameter at zero-based `index`.
    pub inline fn paramName(self: *const FunctionEntry, index: u32) [:0]const u8 {
        return std.mem.span(self.ptr().arg_info[index + 1].name);
    }

    /// Whether the parameter at zero-based `index` must be passed by reference.
    pub inline fn isParamByReference(self: *const FunctionEntry, index: u32) bool {
        return sendMode(self.ptr().arg_info[index + 1]) == c.ZEND_SEND_BY_REF;
    }

    inline fn sendMode(info: c.zend_internal_arg_info) u32 {
        return (info.type.type_mask >> c._ZEND_SEND_MODE_SHIFT) & 0b11;
    }
};

test {
    std.testing.refAllDecls(FunctionEntry);
}
