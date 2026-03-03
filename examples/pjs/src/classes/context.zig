pub const Context = extern struct {
    rt: *runtime.Class,
    core: *quickjs.Context,

    pub fn deinit(self: *Context) void {
        self.core.deinit();
        self.rt.delref();
    }

    pub fn construct(self: *Context, frame: *phpz.CallFrame) !void {
        var php_rt_zv: *c.zval = undefined;
        try frame.parse("O", .{ &php_rt_zv, runtime.Class.entry });
        const php_rt: *phpz.Zval = .from(php_rt_zv);

        self.rt = .from(.std, try php_rt.as(.object));
        self.rt.addref();

        self.core = try .init(self.rt.impl.core);
    }

    pub fn eval(self: *Context, frame: *phpz.CallFrame, ret: *phpz.Zval) !void {
        var code: []u8 = undefined;
        try frame.parse("s", .{ &code.ptr, &code.len });
        if (code.len == 0) return error.NoJavaScriptCode;

        const core = self.core;
        var result = core.eval(code, "<main>", .{});
        errdefer result.deinit(core);

        if (result.isException()) {
            const exc = self.core.getException();
            defer exc.deinit(self.core);
            if (exc.toZigSlice(self.core)) |msg| {
                defer self.core.freeCString(msg.ptr);
                exception.throw(msg);
            } else {
                exception.throw("unknown error");
            }
            return error.JavaScriptException;
        }

        const ctx_obj: *Class = .from(.impl, self);
        const val: *value.Class = .new();
        val.impl.ctx = ctx_obj;
        val.impl.core = result;
        try val.impl.updateValueFromJsValue(result);
        ctx_obj.addref();

        ret.set(.object, &val.std);
    }
};

pub const Class = phpz.Class("Pjs\\Context", Context);

comptime {
    Class.method("__construct", .construct);
    Class.method("eval", .eval);
}

const std = @import("std");

const phpz = @import("phpz");
const c = phpz.c;
const quickjs = @import("quickjs");

const runtime = @import("runtime.zig");
const exception = @import("exception.zig");
const value = @import("value.zig");
