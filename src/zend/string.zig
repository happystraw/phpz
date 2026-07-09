const phpz = @import("../root.zig");
const c = phpz.c;
const globals = phpz.globals;

pub const String = opaque {
    /// Create an empty string.
    ///
    /// Ownership: borrowed interned singleton.
    pub inline fn empty() *String {
        return @ptrCast(globals.global(.value, *c.zend_string, "zend_empty_string"));
    }

    /// Create a single character string.
    ///
    /// Ownership: borrowed interned singleton.
    pub inline fn char(ch: u8) *String {
        const index: usize = ch;
        return @ptrCast(globals.global(.ptr, [256]*c.zend_string, "zend_one_char_string")[index]);
    }

    /// Create a string from a byte slice.
    ///
    /// Ownership: caller owns one logical reference; call `release()` when done.
    /// Empty and one-byte strings may be interned, but `release()` is still valid.
    pub fn init(str: []const u8, persistent: bool) *String {
        if (str.len == 0) return empty();
        if (str.len == 1) return char(str[0]);
        return @ptrCast(c.zend_string_init(str.ptr, str.len, persistent));
    }

    /// Create a string from an existing zend_string pointer.
    ///
    /// Ownership: borrowed wrapper; no refcount change. Use `copy()`/`addref()`
    /// if the wrapper must outlive the original owner.
    pub inline fn from(zstr: *c.zend_string) *String {
        return @ptrCast(zstr);
    }

    /// Get the underlying zend_string pointer.
    ///
    /// Ownership: borrowed raw pointer.
    pub inline fn ptr(self: *String) *c.zend_string {
        return @ptrCast(@alignCast(self));
    }

    /// Get C string pointer (null-terminated).
    ///
    /// Ownership: borrowed view into this string.
    pub inline fn cstr(self: *String) [*:0]const u8 {
        return @ptrCast(self.ptr().val());
    }

    /// Release one owned string reference.
    pub fn release(self: *String) void {
        c.zend_string_release(self.ptr());
    }

    /// Get string length
    pub inline fn len(self: *String) usize {
        return self.ptr().len;
    }

    /// Get string as a slice.
    ///
    /// Ownership: borrowed view into this string.
    pub fn slice(self: *String) []const u8 {
        return self.cstr()[0..self.len()];
    }

    /// Check if string is empty
    pub inline fn isEmpty(self: *String) bool {
        return self.len() == 0;
    }

    /// Copy the string (increment refcount).
    ///
    /// Ownership: caller owns the returned reference; call `release()` when done.
    pub fn copy(self: *String) *String {
        return .from(c.zend_string_copy(self.ptr()));
    }

    /// Concatenate two strings.
    ///
    /// Ownership: caller owns the returned string; call `release()` when done.
    pub fn concat(s1: []const u8, s2: []const u8) *String {
        return .from(c.zend_string_concat2(s1.ptr, s1.len, s2.ptr, s2.len));
    }

    /// Concatenate three strings.
    ///
    /// Ownership: caller owns the returned string; call `release()` when done.
    pub fn concat3(s1: []const u8, s2: []const u8, s3: []const u8) *String {
        return .from(c.zend_string_concat3(
            s1.ptr,
            s1.len,
            s2.ptr,
            s2.len,
            s3.ptr,
            s3.len,
        ));
    }

    /// Convert to lowercase.
    ///
    /// Ownership: caller owns the returned string; call `release()` when done.
    pub fn toLower(self: *String) *String {
        return .from(c.zend_string_tolower_ex(self.ptr(), false));
    }

    /// Convert to uppercase.
    ///
    /// Ownership: caller owns the returned string; call `release()` when done.
    pub fn toUpper(self: *String) *String {
        return .from(c.zend_string_toupper_ex(self.ptr(), false));
    }

    /// Compare string to a string literal
    pub fn equals(self: *String, other: []const u8) bool {
        return c.zend_string_equals_cstr(self.ptr(), other.ptr, other.len);
    }

    /// Compare string to another string
    pub fn equalsString(self: *String, other: *String) bool {
        return c.zend_string_equals(self.ptr(), other.ptr());
    }

    /// Calculate string hash
    pub fn hash(self: *String) u64 {
        return c.zend_string_hash_func(self.ptr());
    }

    /// Check if string starts with a prefix
    pub fn startsWith(self: *String, prefix: []const u8) bool {
        return c.zend_string_starts_with_cstr(self.ptr(), prefix.ptr, prefix.len);
    }

    /// Check if string starts with another string
    pub fn startsWithString(self: *String, prefix: *String) bool {
        return c.zend_string_starts_with(self.ptr(), prefix.ptr());
    }

    /// Get refcount
    pub inline fn refcount(self: *String) u32 {
        return c.zend_gc_refcount(&self.ptr().gc);
    }

    /// Increment refcount.
    ///
    /// Ownership: caller owns the added reference and must release/delref it.
    pub fn addref(self: *String) void {
        _ = c.zend_gc_addref(&self.ptr().gc);
    }

    /// Decrement refcount.
    pub fn delref(self: *String) void {
        _ = c.zend_gc_delref(&self.ptr().gc);
    }

    /// Check if string is interned
    pub inline fn isInterned(self: *String) bool {
        return c.ZSTR_IS_INTERNED(self.ptr()) != 0;
    }
};

test {
    @import("std").testing.refAllDecls(String);
}
