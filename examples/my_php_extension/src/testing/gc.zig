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
        if (self.callback.fci.size != 0) self.callback.addref();
        return self;
    }

    fn deinit(self: *GcNode) void {
        Zval.raw.release(&self.first);
        Zval.raw.release(&self.second);
        if (self.callback.fci.size != 0) {
            self.callback.release();
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
        buffer.addCallable(&self.callback);
    }
};

pub const Class = phpz.Class("MyPHPExt\\Test\\GcNode", GcNode, .{
    .deinit = GcNode.deinit,
    .gc = GcNode.gc,
});
