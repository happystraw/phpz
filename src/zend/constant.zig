const c = @import("../c.zig").c;
const errors = @import("../errors.zig");
const globals = @import("../globals.zig");
const Zval = @import("../zval.zig").Zval;
const ClassEntry = @import("class_entry.zig").ClassEntry;
const String = @import("string.zig").String;

pub const Constant = opaque {
    pub inline fn from(raw: *c.zend_constant) *Constant {
        return @ptrCast(raw);
    }

    pub inline fn ptr(self: *Constant) *c.zend_constant {
        return @ptrCast(@alignCast(self));
    }

    pub fn name(self: *Constant) [:0]const u8 {
        const n = self.ptr().name;
        return n.*.val()[0..n.*.len :0];
    }

    pub inline fn flags(self: *Constant) u32 {
        return c.ZEND_CONSTANT_FLAGS(self.ptr());
    }

    pub inline fn moduleNumber(self: *Constant) u32 {
        return c.ZEND_CONSTANT_MODULE_NUMBER(self.ptr());
    }

    /// Find an exact key in the current thread's global constant table.
    /// Namespace segments in table keys are lowercase; the constant name is case-sensitive.
    /// Does not strip a leading backslash, resolve Class::NAME, or evaluate expressions.
    pub fn find(key: []const u8) ?*Constant {
        const raw = c.zend_hash_str_find_ptr(globals.executor().ptr().zend_constants, key.ptr, key.len);
        return if (raw != null) .from(@ptrCast(@alignCast(raw))) else null;
    }

    /// Resolve a constant through zend_get_constant_ex(). Supports qualified global
    /// names and Class::NAME; scope controls class-constant access and self/parent.
    /// Silent lookup returns null for missing/inaccessible constants.
    /// Evaluation or autoload exceptions are still reported as PhpException.
    ///
    /// Ownership: borrowed value owned by Zend. Do not modify or release it; copy it
    /// before retaining it beyond its owner. Zend bailouts propagate unchanged.
    pub fn get(constant_name: []const u8, scope: ?*ClassEntry, silent: bool) errors.Exception!?*Zval {
        const key = String.init(constant_name, false);
        defer key.release();
        const value = c.zend_get_constant_ex(
            key.ptr(),
            if (scope) |ce| ce.ptr() else null,
            if (silent) c.ZEND_FETCH_CLASS_EXCEPTION | c.ZEND_FETCH_CLASS_SILENT else c.ZEND_FETCH_CLASS_EXCEPTION,
        );
        if (errors.hasException()) return error.PhpException;
        return if (value) |v| .from(v) else null;
    }
};

test {
    @import("std").testing.refAllDecls(Constant);
}
