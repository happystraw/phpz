pub const Runtime = extern struct {
    core: *quickjs.Runtime,

    pub fn init(self: *Runtime) void {
        self.core = quickjs.Runtime.init() catch unreachable;
    }

    pub fn deinit(self: *Runtime) void {
        self.core.deinit();
    }
};

pub const Class = phpz.Class("Pjs\\Runtime", Runtime);

const phpz = @import("phpz");
const quickjs = @import("quickjs");
