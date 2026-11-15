const phpz = @import("phpz");
const Zval = phpz.Zval;
const RetainedCallable = phpz.zend.Callable.Cache;

const GcNode = struct {
    first: phpz.c.zval,
    second: phpz.c.zval,
    callback: RetainedCallable,

    /// PHP: MyPHPExt\Test\GcNode::__construct(mixed $first = null, mixed $second = null, ?callable $callback = null): void
    pub fn __construct(first: ?*Zval, second: ?*Zval, callback: ?phpz.Nullable(*phpz.zend.Callable)) !GcNode {
        var self: GcNode = .{ .first = Zval.raw.undef, .second = Zval.raw.undef, .callback = .nil };
        errdefer self.deinit();
        if (first) |value| Zval.raw.copy(&self.first, value.ptr());
        if (second) |value| Zval.raw.copy(&self.second, value.ptr());
        if (callback) |provided| {
            if (provided.asOptional()) |resolved| {
                const name = phpz.zend.Callable.name(&resolved.fci.function_name, null);
                defer name.release();
                if (name.isEmpty()) return error.EmptyCallableName;
                self.callback = try resolved.retainCache();
            }
        }
        return self;
    }

    /// PHP: MyPHPExt\Test\GcNode::invokeCallback(mixed $value, bool $guarded = false): mixed
    pub fn invokeCallback(self: *GcNode, ctx: phpz.Ctx, value: *Zval, guarded: ?bool) !void {
        if (!self.hasCallback()) return error.MissingCallback;
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
        self.callback.deinit();
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
        self.callback.addToGc(buffer);
    }

    fn hasCallback(self: *GcNode) bool {
        return self.callback.isInitialized();
    }
};

pub const Class = phpz.Class("MyPHPExt\\Test\\GcNode", GcNode, .{
    .deinit = GcNode.deinit,
    .gc = GcNode.gc,
});
