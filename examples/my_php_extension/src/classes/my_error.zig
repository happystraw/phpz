const phpz = @import("phpz");
const c = phpz.c;

const MyError = struct {
    pub fn register(impl: anytype) *phpz.ClassEntry {
        return .from(impl(phpz.globals.class.entry("Exception")));
    }
};

pub const Class = phpz.SimpleClass("MyPHPExt\\MyError", MyError);
