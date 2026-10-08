const std = @import("std");

const phpz = @import("phpz");
const Zval = phpz.Zval;

/// PHP: hello(): void
pub fn hello() void {
    _ = phpz.printf("Hello from ZIG!\n", .{});
}

/// PHP: greet(string $name): string
pub fn greet(name: []const u8) !*phpz.zend.String {
    var buffer: [4096]u8 = undefined;
    const result = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{name});
    return phpz.zend.String.init(result, false);
}

/// PHP: MyPHPExt\increment(int &$value, int $by = 1): void
pub fn increment(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .reference = .{ .kind = .int, .as = .value } },
        .{ .int = .{ .optional = true } },
    }, {});

    const value = args[0];
    const by = args[1] orelse 1;
    const current = value.asUnchecked(.int);
    value.set(.int, current + by);
}

/// PHP: MyPHPExt\mapValues(array $values, callable $mapper): array
pub fn mapValues(ctx: phpz.Ctx, values: *phpz.zend.Array, mapper: *phpz.zend.Callable) !void {
    var result = phpz.Zval.Array.empty(ctx.retval.ptr());
    var iterator = values.fastIterator();
    while (iterator.next()) |entry| {
        var mapped = Zval.raw.undef;
        errdefer Zval.raw.release(&mapped);

        try mapper.call(&mapped, .{entry.value.*}, null);
        switch (entry.key) {
            .string => |key| result.set(.mixed, key, &mapped),
            .int => |key| try result.setAt(.mixed, key, &mapped),
        }
    }
}
