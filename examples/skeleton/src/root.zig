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
    pub fn greet(name: []const u8) !*phpz.zend.String {
        var buffer: [256]u8 = undefined;
        const result = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{name});
        return .init(result, false);
    }
};

// --- Classes ---

/// class Counter
const Counter = struct {
    n: i64 = 0,

    /// public function __construct(int $n = 0): void
    pub fn __construct(n: ?i64) Counter {
        return .{ .n = n orelse 0 };
    }

    /// public function add(int $n): void
    pub fn add(self: *Counter, n: i64) void {
        self.n +|= n;
    }

    /// public function dec(int $n): void
    pub fn dec(self: *Counter, n: i64) void {
        self.n -|= n;
    }

    /// public function value(): int
    pub fn value(self: *const Counter) i64 {
        return self.n;
    }
};
