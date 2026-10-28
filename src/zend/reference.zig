const c = @import("../root.zig").c;
const Zval = @import("../zval.zig").Zval;
const exception = @import("../exception.zig");

pub const Reference = opaque {
    /// Create a PHP reference containing the specified value.
    ///
    /// Ownership: caller owns one reference (refcount 1).
    pub fn init(comptime kind: Zval.Kind, value: Zval.Type(kind)) *Reference {
        comptime checkKind(kind);
        const ref = from(c.phpz_reference_new_empty());
        Zval.raw.set(ref.val(), kind, value);
        return ref;
    }

    pub const SetError = exception.Error;

    /// Set the referenced value, releasing its previous contents.
    /// Preserves aliases and enforces property type constraints.
    /// Transferred inputs are consumed even on failure.
    /// Returns pending PHP exceptions as SetError.
    pub fn set(self: *Reference, comptime kind: Zval.Kind, value: Zval.Type(kind)) SetError!void {
        comptime checkKind(kind);
        var replacement = Zval.raw.init(kind, value);
        c.phpz_reference_assign(self.ptr(), &replacement);
        try exception.check();
    }

    fn checkKind(comptime kind: Zval.Kind) void {
        switch (kind) {
            .undef, .reference, .indirect, .ptr => @compileError("PHP references cannot contain ." ++ @tagName(kind) ++ "; use .mixed to copy a referenced PHP value"),
            else => {},
        }
    }

    /// Create from an existing zend_reference pointer
    pub inline fn from(ref: *c.zend_reference) *Reference {
        return @ptrCast(ref);
    }

    /// Get the underlying zend_reference pointer
    pub inline fn ptr(self: *Reference) *c.zend_reference {
        return @ptrCast(@alignCast(self));
    }

    /// Get the referenced value as a raw zval pointer
    pub inline fn val(self: *Reference) *c.zval {
        return &self.ptr().val;
    }

    /// Get refcount
    pub inline fn refcount(self: *Reference) u32 {
        return c.zend_gc_refcount(&self.ptr().gc);
    }

    /// Increment refcount
    pub fn addref(self: *Reference) void {
        _ = c.zend_gc_addref(&self.ptr().gc);
    }

    /// Decrement refcount without destroying the reference. Do not use for cleanup.
    pub fn delref(self: *Reference) void {
        _ = c.zend_gc_delref(&self.ptr().gc);
    }
};

test {
    @import("std").testing.refAllDecls(Reference);
}
