pub const Exception = extern struct {
    pub fn registerFully(extends: anytype) *phpz.ClassEntry {
        return extends(c.spl_ce_RuntimeException);
    }

    pub fn throws(message: [:0]const u8) void {
        _ = c.zend_throw_exception(Class.entry, message.ptr, 0);
    }
};

pub const throws = Exception.throws;
pub const Class = phpz.Class("Pjs\\Exception", Exception);

const phpz = @import("phpz");
const c = phpz.c;
