const ArrayLike = extern struct {
    data: *phpz.zend.Array,
    iter: phpz.zend.Array.Iterator,

    pub fn register(impl: anytype) *phpz.ClassEntry {
        return .from(impl(c.zend_ce_arrayaccess, c.zend_ce_countable, c.zend_ce_iterator));
    }

    pub fn init(self: *ArrayLike) void {
        self.data = phpz.zend.Array.empty();
        self.iter = self.data.iterator();
    }

    pub fn deinit(self: *ArrayLike) void {
        self.data.release();
    }

    pub fn construct(self: *ArrayLike, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .array = .{ .optional = true } },
        }, {});
        if (args[0]) |arr| {
            self.data.copy(arr);
        }
    }

    pub fn toArray(self: ArrayLike, ctx: phpz.Ctx) void {
        ctx.ret.set(.array, self.data.duplicate());
    }

    // ── ArrayAccess ──────────────────────────────────────────────

    pub fn offsetExists(self: *ArrayLike, ctx: phpz.Ctx) !void {
        var offset: *c.zval = undefined;
        try ctx.call.parse("z", .{&offset});
        ctx.ret.set(.bool, switch (phpz.Zval.native.kind(offset)) {
            .int => self.data.hasIndex(@intCast(phpz.Zval.native.asUnchecked(offset, .int))),
            .string => self.data.has(phpz.Zval.native.asUnchecked(offset, .string)),
            else => false,
        });
    }

    pub fn offsetGet(self: *ArrayLike, ctx: phpz.Ctx) !void {
        var offset: *c.zval = undefined;
        try ctx.call.parse("z", .{&offset});
        const zv = switch (phpz.Zval.native.kind(offset)) {
            .int => self.data.findIndex(@intCast(phpz.Zval.native.asUnchecked(offset, .int))),
            .string => self.data.find(phpz.Zval.native.asUnchecked(offset, .string)),
            else => null,
        };
        if (zv) |v| {
            phpz.Zval.native.tryAddref(v);
            ctx.ret.set(.mixed, v);
        } else {
            ctx.ret.set(.null, {});
        }
    }

    pub fn offsetSet(self: *ArrayLike, ctx: phpz.Ctx) !void {
        var offset: ?*c.zval = null;
        var value: *c.zval = undefined;
        try ctx.call.parse("z!z", .{ &offset, &value });
        phpz.Zval.native.tryAddref(value);
        if (offset) |o| {
            switch (phpz.Zval.native.kind(o)) {
                .int => _ = self.data.updateIndex(@intCast(phpz.Zval.native.asUnchecked(o, .int)), value),
                .string => _ = self.data.update(phpz.Zval.native.asUnchecked(o, .string), value),
                else => {},
            }
        } else {
            _ = self.data.append(value);
        }
        self.iter.reset();
    }

    pub fn offsetUnset(self: *ArrayLike, ctx: phpz.Ctx) !void {
        var offset: *c.zval = undefined;
        try ctx.call.parse("z", .{&offset});
        switch (phpz.Zval.native.kind(offset)) {
            .int => self.data.deleteIndex(@intCast(phpz.Zval.native.asUnchecked(offset, .int))) catch {},
            .string => self.data.delete(phpz.Zval.native.asUnchecked(offset, .string)) catch {},
            else => {},
        }
        self.iter.reset();
    }

    // ── Countable ─────────────────────────────────────────────────

    pub fn count(self: ArrayLike, ctx: phpz.Ctx) void {
        ctx.ret.set(.int, @intCast(self.data.len()));
    }

    // ── Iterator ──────────────────────────────────────────────────

    pub fn current(self: *ArrayLike, ctx: phpz.Ctx) void {
        if (self.iter.currentValue()) |zv| {
            phpz.Zval.native.tryAddref(zv);
            ctx.ret.set(.mixed, zv);
        } else {
            ctx.ret.set(.null, {});
        }
    }

    pub fn key(self: *ArrayLike, ctx: phpz.Ctx) void {
        if (self.iter.currentKey()) |k| {
            switch (k) {
                .int => |i| ctx.ret.set(.int, i),
                .string => |s| ctx.ret.set(.string, s),
            }
        } else {
            ctx.ret.set(.null, {});
        }
    }

    pub fn next(self: *ArrayLike) void {
        self.iter.advance();
    }

    pub fn rewind(self: *ArrayLike) void {
        self.iter.reset();
    }

    pub fn valid(self: *ArrayLike, ctx: phpz.Ctx) void {
        ctx.ret.set(.bool, self.iter.current() != null);
    }
};

pub const Class = phpz.Class("MyPHPExt\\ArrayLike", ArrayLike);

comptime {
    Class.method("__construct", .construct);
    Class.method("toArray", .toArray);
    Class.method("offsetExists", .offsetExists);
    Class.method("offsetGet", .offsetGet);
    Class.method("offsetSet", .offsetSet);
    Class.method("offsetUnset", .offsetUnset);
    Class.method("count", .count);
    Class.method("current", .current);
    Class.method("key", .key);
    Class.method("next", .next);
    Class.method("rewind", .rewind);
    Class.method("valid", .valid);
}

const phpz = @import("phpz");
const c = phpz.c;
