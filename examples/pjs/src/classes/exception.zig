pub const Class = phpz.DerivedClass("Pjs\\Exception", struct {
    pub fn register(extends: anytype) *phpz.ClassEntry {
        return extends(c.spl_ce_RuntimeException);
    }
});

pub fn throw(message: [:0]const u8) void {
    _ = c.zend_throw_exception(Class.entry, message.ptr, 0);
}

const phpz = @import("phpz");
const c = phpz.c;
