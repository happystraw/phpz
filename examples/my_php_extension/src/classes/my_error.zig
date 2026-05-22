const phpz = @import("phpz");
const c = phpz.c;

const MyError = struct {
    pub fn register(impl: anytype) *phpz.ClassEntry {
        return impl(c.zend_ce_exception);
    }
};

pub const Class = phpz.SimpleClass("MyPHPExt\\MyError", MyError);
