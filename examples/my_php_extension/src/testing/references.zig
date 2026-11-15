const std = @import("std");
const phpz = @import("phpz");
const Zval = phpz.Zval;
const Reference = phpz.zend.Reference;

const kinds = .{ .null, .int, .float, .bool, .string, .str, .array, .object, .resource, .mixed };

pub fn makeReference(value: *Zval) *Reference {
    var result = Zval.raw.init(.mixed, value.ptr());
    const wrapped = Zval.from(&result);
    wrapped.makeRef();
    const ref = wrapped.asUnchecked(.reference);
    std.debug.assert(ref.refcount() == 1);

    var alias: phpz.c.zval = undefined;
    Zval.raw.copy(&alias, &result);
    Zval.raw.makeRef(&alias);
    std.debug.assert(Zval.raw.asUnchecked(&alias, .reference) == ref);
    std.debug.assert(ref.refcount() == 2 and !Zval.raw.is(ref.val(), .reference));
    Zval.raw.release(&alias);
    return ref;
}

/// Release a shared reference, then its last owner, around an object that PHP
/// does not hold: only the final release may run its destructor.
pub fn checkReferenceRelease(class_name: []const u8) !void {
    const ce = (try phpz.ClassEntry.lookup(class_name, true)) orelse return error.ClassNotFound;
    const object = try phpz.zend.Object.init(ce);
    const ref = Reference.init(.object, object);
    ref.addref();
    ref.release();
    try std.testing.expectEqual(@as(u32, 1), ref.refcount());
    _ = phpz.printf("released shared\n", .{});
    ref.release();
    _ = phpz.printf("released last\n", .{});
}

pub fn createReference(type_name: []const u8, value: *Zval) !*Reference {
    inline for (kinds) |kind| {
        if (std.mem.eql(u8, type_name, @tagName(kind))) {
            const input = if (kind == .null) {} else try value.as(kind);
            if (comptime kind == .str or kind == .array or kind == .object or kind == .resource) value.tryAddref();
            const ref = Reference.init(kind, input);
            std.debug.assert(ref.refcount() == 1);
            return ref;
        }
    }
    return error.InvalidReferenceKind;
}

pub fn setReference(ref: *Reference, type_name: []const u8, value: *Zval) !void {
    inline for (kinds) |kind| {
        if (std.mem.eql(u8, type_name, @tagName(kind))) {
            const input = if (kind == .null) {} else try value.as(kind);
            if (comptime kind == .str or kind == .array or kind == .object or kind == .resource) value.tryAddref();
            try ref.set(kind, input);
            return;
        }
    }
    return error.InvalidReferenceKind;
}

pub fn setReferenceSelf(ref: *Reference) !void {
    try ref.set(.mixed, ref.val());
}

/// Typed optional by-reference parameter: mark the reference when passed.
pub fn markOptionalReference(ref: ?*Reference) !bool {
    const target = ref orelse return false;
    try target.set(.string, "marked");
    return true;
}

pub fn createReferenceCopy(ref: *Reference) *Reference {
    // Copy from the outer reference too; init must not nest reference containers.
    var outer = Zval.raw.init(.reference, ref);
    const copy = Reference.init(.mixed, &outer);
    std.debug.assert(!Zval.raw.is(copy.val(), .reference));
    return copy;
}
