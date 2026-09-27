const std = @import("std");
const phpz = @import("phpz");

const Value = struct {
    first: i64 = 0,
    second: i64 = 0,
    trace_cleanup: bool = false,

    pub fn __construct(ctx: phpz.Ctx, first: i64, second: ?i64, fail: ?bool) !Value {
        if (fail orelse false) {
            // Trace the already initialized backing when construction fails.
            const instance = try ValueClass.fromObject(ctx.call.this().?);
            instance.backing().?.trace_cleanup = true;
            return phpz.errors.throwError(null, "constructor failed", .{});
        }
        return .{ .first = first, .second = second orelse 7 };
    }

    pub fn values(self: *const Value, ctx: phpz.Ctx) !void {
        try ctx.call.expectNoArgs();
        const result = phpz.Zval.Array.empty(ctx.retval.ptr());
        try result.append(.int, self.first);
        try result.append(.int, self.second);
    }

    pub fn __destruct(self: *const Value) void {
        if (self.trace_cleanup) std.debug.print("PHP destructor\n", .{});
    }

    fn deinit(self: *Value) void {
        if (self.trace_cleanup) std.debug.print("backing cleanup\n", .{});
    }
};

const ValueClass = phpz.Class("MyPHPExt\\Test\\NewValue", Value, .{ .deinit = Value.deinit });
const BareClass = phpz.Class("MyPHPExt\\Test\\NewBare", struct { value: i64 = 0 }, .{});
pub const classes = .{ ValueClass, BareClass };

/// Exercise Class.new()/tryNew() with borrowed positional and named arguments.
pub fn newObject(ctx: phpz.Ctx, bare: bool, positional: *phpz.zend.Array, named: phpz.Nullable(*phpz.zend.Array), guarded: bool) !void {
    if (bare) {
        try create(BareClass, ctx, positional, named.asOptional(), guarded);
    } else {
        try create(ValueClass, ctx, positional, named.asOptional(), guarded);
    }
}

fn create(comptime Class: type, ctx: phpz.Ctx, positional: *phpz.zend.Array, named: ?*phpz.zend.Array, guarded: bool) !void {
    switch (positional.len()) {
        0 => try construct(Class, ctx, .{}, named, guarded),
        1 => try construct(Class, ctx, .{(positional.findIndex(0) orelse return error.InvalidPositionalArguments).*}, named, guarded),
        2 => try construct(Class, ctx, .{
            (positional.findIndex(0) orelse return error.InvalidPositionalArguments).*,
            (positional.findIndex(1) orelse return error.InvalidPositionalArguments).*,
        }, named, guarded),
        else => return error.TooManyTestArguments,
    }
}

fn construct(comptime Class: type, ctx: phpz.Ctx, params: anytype, named: ?*phpz.zend.Array, guarded: bool) !void {
    const instance = if (guarded) try Class.tryNew(params, named) else try Class.new(params, named);
    // Transfer the owned object reference to PHP's return slot.
    ctx.retval.set(.object, instance.object());
}
