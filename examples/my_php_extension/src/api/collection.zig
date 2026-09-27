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

    fn gc(self: *Collection, buffer: *phpz.GcBuffer) void {
        buffer.addArray(self.data);
    }

    /// PHP: MyPHPExt\Collection::__construct(array $values = [])
    pub fn __construct(values: ?*phpz.zend.Array) Collection {
        var self = init();
        if (values) |provided| {
            self.data.copy(provided);
        }
        return self;
    }

    /// PHP: MyPHPExt\Collection::toArray(): array
    pub fn toArray(self: *const Collection) *phpz.zend.Array {
        return self.data.dupe();
    }

    /// PHP: MyPHPExt\Collection::offsetExists(mixed $offset): bool
    pub fn offsetExists(self: *Collection, offset: *Zval) bool {
        return switch (offset.kind()) {
            .int => self.data.hasIndex(@intCast(offset.asUnchecked(.int))),
            .string => self.data.has(offset.asUnchecked(.string)),
            else => false,
        };
    }

    /// PHP: MyPHPExt\Collection::offsetGet(mixed $offset): mixed
    pub fn offsetGet(self: *Collection, offset: *Zval) ?*Zval {
        const value = switch (offset.kind()) {
            .int => self.data.findIndex(@intCast(offset.asUnchecked(.int))),
            .string => self.data.find(offset.asUnchecked(.string)),
            else => null,
        };

        return if (value) |found| .from(found) else null;
    }

    /// PHP: MyPHPExt\Collection::offsetSet(mixed $offset, mixed $value): void
    pub fn offsetSet(self: *Collection, offset: *Zval, value: *Zval) void {
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
    pub fn offsetUnset(self: *Collection, offset: *Zval) void {
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
    pub fn count(self: *const Collection) usize {
        return self.data.len();
    }

    /// PHP: MyPHPExt\Collection::current(): mixed
    pub fn current(self: *Collection) ?*Zval {
        return if (self.iterator.currentValue()) |value| .from(value) else null;
    }

    /// PHP: MyPHPExt\Collection::key(): mixed
    pub fn key(self: *Collection) phpz.Mixed(&.{ .int, .string, .null }) {
        if (self.iterator.currentKey()) |key_value| {
            return switch (key_value) {
                .int => |index| .{ .int = index },
                .string => |key_name| .{ .string = key_name },
            };
        }
        return .null;
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
    pub fn valid(self: *Collection) bool {
        return self.iterator.current() != null;
    }
};

pub const Class = phpz.Class("MyPHPExt\\Collection", Collection, .{
    .init = Collection.init,
    .deinit = Collection.deinit,
    .clone = Collection.clone,
    .register = Collection.register,
    .gc = Collection.gc,
});
