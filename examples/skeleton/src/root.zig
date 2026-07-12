const std = @import("std");

const phpz = @import("phpz");

// Create the PHP class wrapper for the Zig implementation.
const CounterClass = phpz.Class("Counter", Counter);

comptime {
    // Bind Zig functions as methods of the PHP class wrapper.
    CounterClass.method("__construct", .construct);
    CounterClass.method("add", .add);
    CounterClass.method("dec", .dec);
    CounterClass.method("value", .value);
}

comptime {
    // Export Zig functions as PHP global functions.
    phpz.function("hello", hello);
    phpz.function("greet", greet);

    // Create and export the PHP module entry. Listed classes are registered during MINIT.
    phpz.module(.{
        .name = "skeleton",
        .version = "0.1.0",
        .classes = &.{CounterClass},
    });
}

// --- Functions ---

/// function hello(): void
fn hello() void {
    _ = phpz.printf("Hello from Zig!\n", .{});
}

/// function greet(string $name): string
fn greet(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
    }, {});
    const name = args[0];

    var buffer: [256]u8 = undefined;
    const result = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{name});
    ctx.ret.set(.string, result);
}

// --- Classes ---

/// class Counter
pub const Counter = extern struct {
    n: i64,

    /// public function __construct(int $n = 0): void
    pub fn construct(self: *Counter, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{ .optional = true } },
        }, {});
        self.n = args[0] orelse 0;
    }

    /// public function add(int $n): void
    pub fn add(self: *Counter, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{} },
        }, {});
        self.n +|= args[0];
    }

    /// public function dec(int $n): void
    pub fn dec(self: *Counter, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{} },
        }, {});
        self.n -|= args[0];
    }

    /// public function value(): int
    pub fn value(self: Counter, ctx: phpz.Ctx) void {
        ctx.ret.set(.int, self.n);
    }
};
