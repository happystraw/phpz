const std = @import("std");
const phpz = @import("phpz");
const Zval = phpz.Zval;

/// Exercise both API layers from the zval ownership fixture.
pub fn checkRefcounts() !void {
    inline for (.{ false, true }) |wrapped| {
        // A single-owner reference exposes the difference between Z_ADDREF_P
        // and the zval_add_ref copy constructor, which would unwrap it.
        var reference = std.mem.zeroes(phpz.c.zend_reference);
        reference.gc.refcount = 1;
        reference.gc.u.type_info = phpz.c.GC_REFERENCE;
        reference.val = Zval.raw.init(.int, 42);
        var value = Zval.raw.init(.reference, phpz.zend.Reference.from(&reference));
        if (wrapped) Zval.from(&value).addref() else Zval.raw.addref(&value);
        try std.testing.expect(Zval.raw.is(&value, .reference));
        try std.testing.expect(value.value.ref == &reference);
        try std.testing.expectEqual(@as(u32, 2), reference.gc.refcount);
        if (wrapped) Zval.from(&value).delref() else Zval.raw.delref(&value);
        try std.testing.expectEqual(@as(u32, 1), reference.gc.refcount);

        if (wrapped) Zval.from(&value).tryAddref() else Zval.raw.tryAddref(&value);
        try std.testing.expectEqual(@as(u32, 2), reference.gc.refcount);
        if (wrapped) Zval.from(&value).tryDelref() else Zval.raw.tryDelref(&value);
        try std.testing.expectEqual(@as(u32, 1), reference.gc.refcount);
        // This reference is stack-backed; decrement-only APIs must not free it.
        if (wrapped) Zval.from(&value).delref() else Zval.raw.delref(&value);
        try std.testing.expectEqual(@as(u32, 0), reference.gc.refcount);

        var scalars = [_]phpz.c.zval{
            Zval.raw.undef,
            Zval.raw.nil,
            Zval.raw.init(.bool, true),
            Zval.raw.init(.int, 42),
            Zval.raw.init(.float, 1.5),
        };
        for (&scalars) |*scalar| {
            const kind = Zval.raw.kind(scalar);
            if (wrapped) {
                Zval.from(scalar).tryAddref();
                Zval.from(scalar).tryDelref();
                Zval.from(scalar).release();
            } else {
                Zval.raw.tryAddref(scalar);
                Zval.raw.tryDelref(scalar);
                Zval.raw.release(scalar);
            }
            try std.testing.expectEqual(kind, Zval.raw.kind(scalar));
        }
    }
}

/// Shared handler for castValue and castReferenceValue.
pub fn castValue(ctx: phpz.Ctx, value: *Zval, type_name: []const u8, convert: bool) !void {
    inline for (.{ .int, .float, .bool, .str, .array, .object }) |kind| {
        if (std.mem.eql(u8, type_name, if (kind == .str) "string" else @tagName(kind))) {
            if (convert) {
                Zval.raw.copy(ctx.retval.ptr(), value.ptr());
                _ = try ctx.retval.convert(kind);
            } else {
                const result = try value.cast(kind);
                ctx.retval.set(kind, result);
            }
            return;
        }
    }
    return error.UnknownCastType;
}
