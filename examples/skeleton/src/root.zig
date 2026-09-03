const std = @import("std");

const phpz = @import("phpz");

comptime {
    const extension = @import("extension_info");

    // Export every public function declared by functions.
    phpz.functions(functions, .{});

    // Create and export the PHP module entry. Listed classes are registered during MINIT.
    phpz.module(.{
        .name = extension.name,
        .version = extension.version,
        .classes = &.{
            // Create the PHP class wrapper and export all public methods.
            phpz.Class("Counter", Counter, .{}),
        },
    });
}

// --- Functions ---

const functions = struct {
    /// function hello(): void
    pub fn hello() void {
        _ = phpz.printf("Hello from Zig!\n", .{});
    }

    /// function greet(string $name): string
    pub fn greet(ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .string = .{} },
        }, {});
        const name = args[0];

        var buffer: [256]u8 = undefined;
        const result = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{name});
        ctx.ret.set(.string, result);
    }
};

// --- Classes ---

/// class Counter
const Counter = struct {
    n: i64,

    /// public function __construct(int $n = 0): void
    pub fn __construct(ctx: phpz.Ctx) !Counter {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{ .optional = true } },
        }, {});
        return .{ .n = args[0] orelse 0 };
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
    pub fn value(self: *const Counter, ctx: phpz.Ctx) void {
        ctx.ret.set(.int, self.n);
    }
};
