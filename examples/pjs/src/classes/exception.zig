pub fn register(extends: anytype) *phpz.ClassEntry {
    return extends(c.spl_ce_RuntimeException);
}

pub fn throw(message: [:0]const u8) void {
    _ = errors.throwException(Class.entry, message);
}

pub const Class = phpz.SimpleClass("Pjs\\Exception", @This());

const phpz = @import("phpz");
const c = phpz.c;
const errors = phpz.errors;
