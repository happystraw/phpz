pub const Runtime = extern struct {
    inner: *quickjs.Runtime,

    pub fn init(self: *Runtime) void {
        self.inner = quickjs.Runtime.init() catch unreachable;
    }

    pub fn deinit(self: *Runtime) void {
        self.inner.deinit();
    }
};

pub const Class = phpz.Class("Pjs\\Runtime", Runtime);

const phpz = @import("phpz");
const quickjs = @import("quickjs");
