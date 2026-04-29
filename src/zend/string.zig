const phpz = @import("../root.zig");
const c = phpz.c;

pub const String = opaque {
    /// Create an empty string
    pub inline fn empty() *String {
        return @ptrCast(@alignCast(c.zend_empty_string));
    }

    /// Create a single character string
    pub inline fn char(ch: u8) *String {
        return @ptrCast(@alignCast(c.zend_one_char_string[ch]));
    }

    /// Create a string from a byte slice
    pub fn init(str: []const u8) *String {
        if (str.len == 0) return empty();
        if (str.len == 1) return char(str[0]);
        return @ptrCast(c.zend_string_init(str.ptr, str.len, false));
    }

    /// Create a string from an existing zend_string pointer
    pub inline fn from(zstr: *c.zend_string) *String {
        return @ptrCast(zstr);
    }

    /// Get the underlying zend_string pointer
    pub inline fn ptr(self: *String) *c.zend_string {
        return @ptrCast(@alignCast(self));
    }

    /// Get C string pointer (null-terminated)
    pub inline fn cstr(self: *String) [*:0]const u8 {
        return @ptrCast(self.ptr().val());
    }

    /// Release the string
    pub fn deinit(self: *String) void {
        c.zend_string_release(self.ptr());
    }

    /// Get string length
    pub inline fn len(self: *String) usize {
        return self.ptr().len;
    }

    /// Get string as a slice
    pub fn slice(self: *String) []const u8 {
        return self.cstr()[0..self.len()];
    }

    /// Check if string is empty
    pub inline fn isEmpty(self: *String) bool {
        return self.len() == 0;
    }

    /// Concatenate two strings
    pub fn concat(s1: []const u8, s2: []const u8) *String {
        const result = c.zend_string_concat2(s1.ptr, s1.len, s2.ptr, s2.len);
        return .from(result);
    }

    /// Concatenate three strings
    pub fn concat3(s1: []const u8, s2: []const u8, s3: []const u8) *String {
        const result = c.zend_string_concat3(
            s1.ptr,
            s1.len,
            s2.ptr,
            s2.len,
            s3.ptr,
            s3.len,
        );
        return .from(result);
    }

    /// Convert to lowercase
    pub fn toLower(self: *String) *String {
        const result = c.zend_string_tolower_ex(self.ptr(), false);
        return .from(result);
    }

    /// Convert to uppercase
    pub fn toUpper(self: *String) *String {
        const result = c.zend_string_toupper_ex(self.ptr(), false);
        return .from(result);
    }

    /// Compare two strings for equality
    pub fn equals(self: *String, other: *String) bool {
        return c.zend_string_equal_val(self.ptr(), other.ptr());
    }

    /// Check if string contains only ASCII alphanumeric characters
    pub fn isAlphanumeric(self: *String) bool {
        return c.zend_string_only_has_ascii_alphanumeric(self.ptr());
    }

    /// Calculate string hash
    pub fn hash(self: *String) u64 {
        return c.zend_string_hash_func(self.ptr());
    }

    /// Get refcount
    pub inline fn refcount(self: *String) u32 {
        return c.zend_gc_refcount(&self.ptr().gc);
    }

    /// Increment refcount
    pub fn addref(self: *String) void {
        _ = c.zend_gc_addref(&self.ptr().gc);
    }

    /// Decrement refcount
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
