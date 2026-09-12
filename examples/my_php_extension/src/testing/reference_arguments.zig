const std = @import("std");
const phpz = @import("phpz");
const Kind = phpz.CallFrame.ExpectArgKind;

/// PHP: MyPHPExt\Test\referenceArgument(string $mode, string $type, bool $optional, bool $single, mixed &$value = null): string
pub fn referenceArgument(ctx: phpz.Ctx) !void {
    try ctx.call.expectArgCount(4, 5);
    const mode = try ctx.call.expectArg(1, .{ .string = .{} }, {});
    const type_name = try ctx.call.expectArg(2, .{ .string = .{} }, {});
    const optional = try ctx.call.expectArg(3, .{ .bool = .{} }, {});
    const single = try ctx.call.expectArg(4, .{ .bool = .{} }, {});

    inline for (.{ false, true }) |is_optional| {
        if (optional == is_optional) {
            inline for (.{ "reference", "zval", "value" }) |result| {
                if (std.mem.eql(u8, mode, result)) {
                    inline for ([_]?Kind{ null, .null, .int, .float, .string, .bool, .array, .object, .resource, .callable }) |kind| {
                        if (std.mem.eql(u8, type_name, if (kind) |k| @tagName(k) else "any")) {
                            const spec: Kind.Spec = comptime spec: {
                                var spec: Kind.Spec = .{ .reference = .{ .optional = is_optional, .type = kind } };
                                if (std.mem.eql(u8, result, "zval")) spec.reference.result = .zval;
                                if (std.mem.eql(u8, result, "value")) spec.reference.result = .value;
                                break :spec spec;
                            };
                            return inspect(ctx, spec, single);
                        }
                    }
                }
            }
        }
    }
    return error.InvalidReferenceTestOptions;
}

fn inspect(ctx: phpz.Ctx, comptime spec: Kind.Spec, single: bool) !void {
    const parsed = if (single)
        try ctx.call.expectArg(5, spec, {})
    else result: {
        const args = try ctx.call.expectArgs(&.{
            .{ .string = .{} },
            .{ .string = .{} },
            .{ .bool = .{} },
            .{ .bool = .{} },
            spec,
        }, {});
        break :result args[4];
    };
    const Expected = switch (spec.reference.result) {
        .reference => *phpz.zend.Reference,
        .zval, .value => *phpz.Zval,
    };
    comptime {
        if (@TypeOf(parsed) != (if (spec.reference.optional) ?Expected else Expected)) {
            @compileError("unexpected reference argument result type");
        }
    }
    const value = if (comptime spec.reference.optional) parsed orelse {
        ctx.ret.set(.string, "omitted");
        return;
    } else parsed;

    const outer = ctx.call.arg(5);
    const reference = phpz.Zval.raw.asUnchecked(outer, .reference);
    const inner: *phpz.Zval = switch (comptime spec.reference.result) {
        .reference => blk: {
            if (value != reference) return error.UnexpectedReferencePointer;
            break :blk .from(value.val());
        },
        .zval => blk: {
            if (value.ptr() != outer or !value.is(.reference)) return error.UnexpectedReferenceZval;
            break :blk .from(value.asUnchecked(.reference).val());
        },
        .value => blk: {
            if (value.ptr() != reference.val() or value.ptr() == outer) return error.UnexpectedReferencedValue;
            break :blk value;
        },
    };
    if (inner.is(.int)) inner.set(.int, inner.asUnchecked(.int) + 1);
    ctx.ret.set(.string, @tagName(inner.kind()));
}
