pub const Value = extern struct {
    ctx: ?*context.Class,
    inner: quickjs.Value,

    pub fn register(impl: anytype) *phpz.ClassEntry {
        return .from(impl(c.zend_ce_stringable));
    }

    pub fn init(self: *Value) void {
        self.inner = .undefined;
    }

    pub fn deinit(self: *Value) void {
        if (self.ctx) |ctx_obj| {
            if (ctx_obj.impl.inner) |js_ctx| self.inner.deinit(js_ctx);
            ctx_obj.release();
        }
    }

    pub fn construct(self: *Value, ctx: phpz.Ctx) !void {
        self.ctx = null;

        const ctx_obj: *phpz.zend.Object, const value_zv: ?*c.zval = try ctx.call.expectArgs(&.{
            .{ .expect_type = .object, .class = context.Class },
            .{ .expect_type = .mixed, .optional = true },
        });

        self.ctx = .from(.std, ctx_obj.ptr());
        self.ctx.?.addref();

        if (value_zv) |value| {
            self.updateValue(.from(value)) catch return errors.argumentTypeError(
                2,
                "must be int|float|string|bool|null, unsupported value type '%s'",
                .{phpz.Zval.native.kind(value).cstr()},
            );
        } else {
            const php_obj: *Class = .from(.impl, self);
            try php_obj.updateProperty(.null, "value", {});
            self.inner = .null;
        }
    }

    /// Returns the inner quickjs Context from the linked Pjs\Context object.
    /// Only valid for fully-constructed Value instances.
    fn innerCtx(self: *Value) *quickjs.Context {
        return self.ctx.?.impl.inner.?;
    }

    fn updateValue(self: *Value, zv: *phpz.Zval) !void {
        const php_obj: *Class = .from(.impl, self);
        switch (zv.kind()) {
            .null => {
                try php_obj.updateProperty(.null, "value", {});
                self.inner = .null;
            },
            .bool => {
                try php_obj.updateProperty(.bool, "value", zv.asUnchecked(.bool));
                self.inner = .initBool(zv.asUnchecked(.bool));
            },
            .int => {
                try php_obj.updateProperty(.int, "value", zv.asUnchecked(.int));
                self.inner = .initInt64(zv.asUnchecked(.int));
            },
            .float => {
                try php_obj.updateProperty(.float, "value", zv.asUnchecked(.float));
                self.inner = .initFloat64(zv.asUnchecked(.float));
            },
            .string => {
                try php_obj.updateProperty(.string, "value", zv.asUnchecked(.string));
                self.inner = .initStringLen(self.innerCtx(), zv.asUnchecked(.string));
            },
            // TODO: more types
            else => return error.Unsupported,
        }
    }

    pub fn updateValueFromJsValue(self: *Value, js_value: quickjs.Value) !void {
        const php_obj: *Class = .from(.impl, self);
        if (js_value.isNull()) {
            try php_obj.updateProperty(.null, "value", {});
            return;
        }
        if (js_value.isNumber()) {
            try php_obj.updateProperty(.float, "value", try js_value.toFloat64(self.innerCtx()));
            return;
        }

        if (js_value.isBool()) {
            try php_obj.updateProperty(.bool, "value", try js_value.toBool(self.innerCtx()));
            return;
        }

        // fallback to string
        // TODO: more type...
        const js_ctx = self.innerCtx();
        var str_val = js_value.toStringValue(js_ctx);
        defer str_val.deinit(js_ctx);
        if (str_val.toZigSlice(js_ctx)) |msg| {
            defer js_ctx.freeCString(msg.ptr);
            try php_obj.updateProperty(.string, "value", msg);
        }
    }

    pub fn toString(self: *Value, ctx: phpz.Ctx) !void {
        const js_ctx = self.innerCtx();
        var str_val = self.inner.toStringValue(js_ctx);
        defer str_val.deinit(js_ctx);

        if (str_val.toZigSlice(js_ctx)) |msg| {
            defer js_ctx.freeCString(msg.ptr);
            ctx.ret.set(.string, msg);
            return;
        }

        ctx.ret.set(.string, "");
    }
};

pub const Class = phpz.Class("Pjs\\Value", Value);

comptime {
    Class.method("__construct", .construct);
    Class.method("__toString", .toString);
}

const std = @import("std");

const phpz = @import("phpz");
const c = phpz.c;
const errors = phpz.errors;
const quickjs = @import("quickjs");

const context = @import("context.zig");
