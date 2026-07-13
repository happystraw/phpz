const std = @import("std");

const phpz = @import("phpz");
const Zval = phpz.Zval;

/// PHP: hello(): void
fn hello() void {
    _ = phpz.printf("Hello from ZIG!\n", .{});
}

/// PHP: greet(string $name): string
fn greet(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
    }, {});

    var buffer: [4096]u8 = undefined;
    const result = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{args[0]});
    ctx.ret.set(.string, result);
}

/// PHP: MyPHPExt\increment(int &$value, int $by = 1): void
fn increment(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .reference = .{} },
        .{ .int = .{ .optional = true } },
    }, {});

    const value = args[0].val();
    const by = args[1] orelse 1;
    const current = Zval.raw.asUnchecked(value, .int);
    Zval.raw.set(value, .int, current + by);
}

/// PHP: MyPHPExt\mapValues(array $values, callable $mapper): array
fn mapValues(ctx: phpz.Ctx) !void {
    var mapper: phpz.zend.Callable = .nil;
    const values, _ = try ctx.call.expectArgs(
        &.{
            .{ .array = .{} },
            .{ .callable = .{ .resolve = true } },
        },
        .{
            {},
            .{ .target = &mapper },
        },
    );

    var result = phpz.Zval.Array.empty(ctx.ret.ptr());
    var iterator = values.fastIterator();
    while (iterator.next()) |entry| {
        var mapped = Zval.raw.undef;
        defer Zval.raw.tryDtor(&mapped);

        try mapper.withRetval(&mapped).call(.{entry.value.*});
        switch (entry.key) {
            .string => |key| result.set(.mixed, key, &mapped),
            .int => |key| try result.setAt(.mixed, key, &mapped),
        }
    }
}

comptime {
    phpz.function("hello", hello);
    phpz.function("greet", greet);
    phpz.function("MyPHPExt\\increment", increment);
    phpz.function("MyPHPExt\\mapValues", mapValues);
}
