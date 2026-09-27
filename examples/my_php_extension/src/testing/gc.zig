const phpz = @import("phpz");
const Zval = phpz.Zval;

const GcNode = struct {
    first: phpz.c.zval,
    second: phpz.c.zval,
    callback: phpz.zend.Callable,

    /// PHP: MyPHPExt\Test\GcNode::__construct(mixed $first = null, mixed $second = null, ?callable $callback = null): void
    pub fn __construct(first: ?*Zval, second: ?*Zval, callback: ?phpz.Nullable(*phpz.zend.Callable)) GcNode {
        var self: GcNode = .{ .first = Zval.raw.undef, .second = Zval.raw.undef, .callback = .nil };
        if (first) |value| Zval.raw.copy(&self.first, value.ptr());
        if (second) |value| Zval.raw.copy(&self.second, value.ptr());
        if (callback) |provided| {
            if (provided.asOptional()) |resolved| {
                // Copy the borrowed call info and retain its PHP references.
                self.callback = resolved.*;
                self.callback.addref();
            }
        }
        return self;
    }

    /// PHP: MyPHPExt\Test\GcNode::invokeCallback(mixed $value, bool $guarded = false): mixed
    pub fn invokeCallback(self: *GcNode, ctx: phpz.Ctx, value: *Zval, guarded: ?bool) !void {
        if (self.callback.fci.size == 0) return error.MissingCallback;
        const params = .{value.ptr().*};
        if (guarded orelse false) {
            try self.callback.tryCall(ctx.retval.ptr(), params, null);
        } else {
            try self.callback.call(ctx.retval.ptr(), params, null);
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
