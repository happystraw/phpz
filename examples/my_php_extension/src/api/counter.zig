const Counter = struct {
    current_value: i64,

    /// PHP: MyPHPExt\Counter::__construct(int $value = 0): void
    pub fn __construct(initial: ?i64) Counter {
        return .{ .current_value = initial orelse 0 };
    }

    /// PHP: MyPHPExt\Counter::increment(int $by = 1): int
    pub fn increment(self: *Counter, by: ?i64) i64 {
        self.current_value +|= by orelse 1;
        return self.current_value;
    }

    /// PHP: MyPHPExt\Counter::decrement(int $by = 1): int
    pub fn decrement(self: *Counter, by: ?i64) i64 {
        self.current_value -|= by orelse 1;
        return self.current_value;
    }

    /// PHP: MyPHPExt\Counter::value(): int
    pub fn value(self: *const Counter) i64 {
        return self.current_value;
    }

    /// PHP: MyPHPExt\Counter::reset(int $value = 0): void
    pub fn reset(self: *Counter, initial: ?i64) void {
        self.current_value = initial orelse 0;
    }
};

pub const Class = phpz.Class("MyPHPExt\\Counter", Counter, .{});

const phpz = @import("phpz");
