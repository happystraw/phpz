pub const Context = extern struct {
    rt: *runtime.Class,
    inner: *quickjs.Context,

    pub fn deinit(self: *Context) void {
        self.inner.deinit();
        self.rt.delref();
    }

    pub fn construct(self: *Context, ctx: phpz.Ctx) !void {
        var rt_zv: *c.zval = undefined;
        try ctx.call.parse("O", .{ &rt_zv, runtime.Class.entry.ptr() });

        self.rt = .fromObjectZval(try .from(rt_zv));
        self.rt.addref();

        self.inner = try .init(self.rt.impl.inner);
    }

    pub fn eval(self: *Context, ctx: phpz.Ctx) !void {
        var code: []u8 = undefined;
        try ctx.call.parse("s", .{ &code.ptr, &code.len });
        if (code.len == 0) return error.NoJavaScriptCode;

        const inner = self.inner;
        var result = inner.eval(code, "<main>", .{});
        errdefer result.deinit(inner);

        if (result.isException()) {
            const exc = self.inner.getException();
            defer exc.deinit(self.inner);
            if (exc.toZigSlice(self.inner)) |msg| {
                defer self.inner.freeCString(msg.ptr);
                exception.throw(msg);
            } else {
                exception.throw("unknown error");
            }
            return error.JavaScriptException;
        }

        const ctx_obj: *Class = .from(.impl, self);
        const val: *value.Class = .new();
        val.impl.ctx = ctx_obj;
        val.impl.inner = result;
        try val.impl.updateValueFromJsValue(result);
        ctx_obj.addref();

        ctx.ret.set(.object, phpz.zend.Object.from(&val.std));
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

const exception = @import("exception.zig");
const runtime = @import("runtime.zig");
const value = @import("value.zig");
