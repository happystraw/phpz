const phpz = @import("phpz");
const Zval = phpz.Zval;

const Collection = struct {
    data: *phpz.zend.Array,
    iterator: phpz.zend.Array.Iterator,

    fn register(register_fn: anytype) *phpz.ClassEntry {
        return register_fn(.{
            phpz.globals.class.entry("ArrayAccess"),
            phpz.globals.class.entry("Countable"),
            phpz.globals.class.entry("Iterator"),
        });
    }

    fn init() Collection {
        const data = phpz.zend.Array.empty();
        return .{ .data = data, .iterator = data.iterator() };
    }

    fn deinit(self: *Collection) void {
        self.data.release();
    }

    fn clone(self: *const Collection) Collection {
        const data = self.data.dupe();
        return .{ .data = data, .iterator = data.iterator() };
    }

    fn gc(self: *Collection, collector: *phpz.Gc) void {
        collector.addArray(self.data);
    }

    /// PHP: MyPHPExt\Collection::__construct(array $values = [])
    pub fn __construct(ctx: phpz.Ctx) !Collection {
        const args = try ctx.call.expectArgs(&.{
            .{ .array = .{ .optional = true } },
        }, {});

        var self = init();
        if (args[0]) |values| {
            self.data.copy(values);
        }
        return self;
    }

    /// PHP: MyPHPExt\Collection::toArray(): array
    pub fn toArray(self: *const Collection, ctx: phpz.Ctx) void {
        ctx.ret.set(.array, self.data.dupe());
    }

    /// PHP: MyPHPExt\Collection::offsetExists(mixed $offset): bool
    pub fn offsetExists(self: *Collection, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .mixed = .{} },
        }, {});
        const offset = Zval.from(args[0]);

        ctx.ret.set(.bool, switch (offset.kind()) {
            .int => self.data.hasIndex(@intCast(offset.asUnchecked(.int))),
            .string => self.data.has(offset.asUnchecked(.string)),
            else => false,
        });
    }

    /// PHP: MyPHPExt\Collection::offsetGet(mixed $offset): mixed
    pub fn offsetGet(self: *Collection, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .mixed = .{} },
        }, {});
        const offset = Zval.from(args[0]);

        const value = switch (offset.kind()) {
            .int => self.data.findIndex(@intCast(offset.asUnchecked(.int))),
            .string => self.data.find(offset.asUnchecked(.string)),
            else => null,
        };

        if (value) |found| {
            Zval.raw.tryAddref(found);
            ctx.ret.set(.mixed, found);
        } else {
            ctx.ret.set(.null, {});
        }
    }

    /// PHP: MyPHPExt\Collection::offsetSet(mixed $offset, mixed $value): void
    pub fn offsetSet(self: *Collection, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .mixed = .{} },
            .{ .mixed = .{} },
        }, {});
        const offset = Zval.from(args[0]);
        const value = Zval.from(args[1]);

        switch (offset.kind()) {
            .int => {
                value.tryAddref();
                _ = self.data.updateIndex(
                    @intCast(offset.asUnchecked(.int)),
                    value.ptr(),
                );
            },
            .string => {
                value.tryAddref();
                _ = self.data.update(
                    offset.asUnchecked(.string),
                    value.ptr(),
                );
            },
            .null => {
                value.tryAddref();
                _ = self.data.append(value.ptr());
            },
            else => return,
        }

        self.iterator.reset();
    }

    /// PHP: MyPHPExt\Collection::offsetUnset(mixed $offset): void
    pub fn offsetUnset(self: *Collection, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .mixed = .{} },
        }, {});
        const offset = Zval.from(args[0]);

        switch (offset.kind()) {
            .int => self.data.deleteIndex(
                @intCast(offset.asUnchecked(.int)),
            ) catch {},
            .string => self.data.delete(
                offset.asUnchecked(.string),
            ) catch {},
            else => {},
        }

        self.iterator.reset();
    }

    /// PHP: MyPHPExt\Collection::count(): int
    pub fn count(self: *const Collection, ctx: phpz.Ctx) void {
        ctx.ret.set(.int, @intCast(self.data.len()));
    }

    /// PHP: MyPHPExt\Collection::current(): mixed
    pub fn current(self: *Collection, ctx: phpz.Ctx) void {
        if (self.iterator.currentValue()) |value| {
            Zval.raw.tryAddref(value);
            ctx.ret.set(.mixed, value);
        } else {
            ctx.ret.set(.null, {});
        }
    }

    /// PHP: MyPHPExt\Collection::key(): mixed
    pub fn key(self: *Collection, ctx: phpz.Ctx) void {
        if (self.iterator.currentKey()) |key_value| {
            switch (key_value) {
                .int => |index| ctx.ret.set(.int, index),
                .string => |key_name| ctx.ret.set(.string, key_name),
            }
        } else {
            ctx.ret.set(.null, {});
        }
    }

    /// PHP: MyPHPExt\Collection::next(): void
    pub fn next(self: *Collection) void {
        self.iterator.advance();
    }

    /// PHP: MyPHPExt\Collection::rewind(): void
    pub fn rewind(self: *Collection) void {
        self.iterator.reset();
    }

    /// PHP: MyPHPExt\Collection::valid(): bool
    pub fn valid(self: *Collection, ctx: phpz.Ctx) void {
        ctx.ret.set(.bool, self.iterator.current() != null);
    }
};

pub const Class = phpz.Class("MyPHPExt\\Collection", Collection, .{
    .init = Collection.init,
    .deinit = Collection.deinit,
    .clone = Collection.clone,
    .register = Collection.register,
    .gc = Collection.gc,
});
