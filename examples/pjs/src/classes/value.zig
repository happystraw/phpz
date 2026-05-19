pub const Value = extern struct {
    ctx: *context.Class,
    core: quickjs.Value,

    pub fn register(impl: anytype) *phpz.ClassEntry {
        return impl(c.zend_ce_stringable);
    }

    pub fn init(self: *Value) void {
        self.core = .undefined;
    }

    pub fn deinit(self: *Value) void {
        self.core.deinit(self.ctx.impl.core);
        self.ctx.delref();
    }

    pub fn construct(self: *Value, ctx: phpz.Ctx) !void {
        var php_ctx_zv: *c.zval = undefined;
        var php_value: phpz.Zval.Optional = .init;
        try ctx.call.parse("O|z", .{ &php_ctx_zv, context.Class.entry, &php_value.ptr });
        const php_ctx_obj: *phpz.Zval.Object = try .from(php_ctx_zv);

        self.ctx = .from(.std, php_ctx_obj.object());
        self.ctx.addref();

        if (php_value.unwrap()) |value| {
            self.updateValue(value) catch return errors.argumentTypeError(
                2,
                "must be int|float|string|bool|null, unsupported value type '%s'",
                .{@tagName(value.kind()).ptr},
            );
        } else {
            const php_obj: *Class = .from(.impl, self);
            php_obj.updateProperty(.null, "value", {});
            self.core = .null;
        }
    }

    fn updateValue(self: *Value, zv: *phpz.Zval) !void {
        const php_obj: *Class = .from(.impl, self);
        switch (zv.kind()) {
            .null => {
                php_obj.updateProperty(.null, "value", {});
                self.core = .null;
            },
            .bool => {
                php_obj.updateProperty(.bool, "value", zv.asUnchecked(.bool));
                self.core = .initBool(zv.asUnchecked(.bool));
            },
            .int => {
                php_obj.updateProperty(.int, "value", zv.asUnchecked(.int));
                self.core = .initInt64(zv.asUnchecked(.int));
            },
            .float => {
                php_obj.updateProperty(.float, "value", zv.asUnchecked(.float));
                self.core = .initFloat64(zv.asUnchecked(.float));
            },
            .string => {
                php_obj.updateProperty(.string, "value", zv.asUnchecked(.string));
                self.core = .initStringLen(self.ctx.impl.core, zv.asUnchecked(.string));
            },
            // TODO: more types
            else => return error.Unsupported,
        }
    }

    pub fn updateValueFromJsValue(self: *Value, js_value: quickjs.Value) !void {
        const php_obj: *Class = .from(.impl, self);
        if (js_value.isNull()) {
            php_obj.updateProperty(.null, "value", {});
            return;
        }
        if (js_value.isNumber()) {
            php_obj.updateProperty(.float, "value", try js_value.toFloat64(self.ctx.impl.core));
            return;
        }

        if (js_value.isBool()) {
            php_obj.updateProperty(.bool, "value", try js_value.toBool(self.ctx.impl.core));
            return;
        }

        // fallback to string
        // TODO: more type...
        var str_val = js_value.toStringValue(self.ctx.impl.core);
        defer str_val.deinit(self.ctx.impl.core);
        if (str_val.toZigSlice(self.ctx.impl.core)) |msg| {
            defer self.ctx.impl.core.freeCString(msg.ptr);
            php_obj.updateProperty(.string, "value", msg);
        }
    }

    pub fn toString(self: *Value, ctx: phpz.Ctx) !void {
        var str_val = self.core.toStringValue(self.ctx.impl.core);
        defer str_val.deinit(self.ctx.impl.core);

        if (str_val.toZigSlice(self.ctx.impl.core)) |msg| {
            defer self.ctx.impl.core.freeCString(msg.ptr);
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
