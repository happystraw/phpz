const phpz = @import("phpz");
const Zval = phpz.Zval;

const GcNode = struct {
    first: phpz.c.zval,
    second: phpz.c.zval,
    callback: phpz.zend.Callable,

    /// PHP: MyPHPExt\Test\GcNode::__construct(mixed $first = null, mixed $second = null, ?callable $callback = null): void
    pub fn __construct(ctx: phpz.Ctx) !GcNode {
        var callback: phpz.zend.Callable = .nil;
        const args = try ctx.call.expectArgs(&.{
            .{ .mixed = .{ .optional = true } },
            .{ .mixed = .{ .optional = true } },
            .{ .callable = .{ .optional = true, .nullable = true, .resolve = true } },
        }, .{ {}, {}, .{ .target = &callback } });
        var self: GcNode = .{ .first = Zval.raw.undef, .second = Zval.raw.undef, .callback = callback };
        if (args[0]) |value| Zval.raw.copy(&self.first, value.ptr());
        if (args[1]) |value| Zval.raw.copy(&self.second, value.ptr());
        // Parsing borrows the callable; retain it beyond this constructor call.
        if (self.callback.fci.size != 0) self.callback.addref();
        return self;
    }

    /// PHP: MyPHPExt\Test\GcNode::invokeCallback(mixed $value, bool $guarded = false): mixed
    pub fn invokeCallback(self: *GcNode, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .mixed = .{} },
            .{ .bool = .{ .optional = true } },
        }, {});
        if (self.callback.fci.size == 0) return error.MissingCallback;
        const params = .{args[0].ptr().*};
        if (args[1] orelse false) {
            try self.callback.tryCall(ctx.ret.ptr(), params, null);
        } else {
            try self.callback.call(ctx.ret.ptr(), params, null);
        }
    }

    fn deinit(self: *GcNode) void {
        Zval.raw.release(&self.first);
        Zval.raw.release(&self.second);
        if (self.callback.fci.size != 0) {
            // Balance the reference acquired by the constructor.
            self.callback.delref();
        }
    }

    fn gc(self: *GcNode, buffer: *phpz.GcBuffer) void {
        const first = Zval.from(&self.first);
        switch (first.kind()) {
            .object => buffer.addObject(first.asUnchecked(.object)),
            .array => buffer.addArray(first.asUnchecked(.array)),
            else => buffer.add(first),
        }
        buffer.add(.from(&self.second));
        // The retained callable may capture this node and form a cycle.
        buffer.addCallable(&self.callback);
    }
};

pub const Class = phpz.Class("MyPHPExt\\Test\\GcNode", GcNode, .{
    .deinit = GcNode.deinit,
    .gc = GcNode.gc,
});
