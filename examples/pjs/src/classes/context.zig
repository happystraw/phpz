pub const Context = extern struct {
    rt: ?*runtime.Class,
    inner: ?*quickjs.Context,

    pub fn init(self: *Context) void {
        self.rt = null;
        self.inner = null;
    }

    pub fn deinit(self: *Context) void {
        if (self.inner) |inner| inner.deinit();
        if (self.rt) |rt| rt.release();
    }

    pub fn construct(self: *Context, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .object = .{ .instanceof = true } },
        }, .{
            .{ .class = runtime.Class.entry },
        });

        self.rt = .from(.std, args[0].ptr());
        self.rt.?.addref();

        self.inner = try .init(self.rt.?.impl.inner);
    }

    pub fn eval(self: *Context, ctx: phpz.Ctx) !void {
        var code: []u8 = undefined;
        try ctx.call.parse("s", .{ &code.ptr, &code.len });
        if (code.len == 0) return error.NoJavaScriptCode;

        const inner = self.inner.?;
        var result = inner.eval(code, "<main>", .{});
        errdefer result.deinit(inner);

        if (result.isException()) {
            const exc = inner.getException();
            defer exc.deinit(inner);
            if (exc.toZigSlice(inner)) |msg| {
                defer inner.freeCString(msg.ptr);
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
