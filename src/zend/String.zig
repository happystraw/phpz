const String = @This();

inner: *c.zend_string,

pub const Error = error{
    AllocationFailed,
};

pub inline fn empty() String {
    return .{ .inner = @ptrCast(c.zend_empty_string) };
}

pub inline fn char(ch: u8) String {
    return .{ .inner = @ptrCast(c.zend_one_char_string[ch]) };
}

pub fn init(str: []const u8) String {
    if (str.len == 0) return .empty();
    if (str.len == 1) return char(str[0]);

    // NOTE: use direct allocation, avoid zend_string_init function(cause index out of bound error)
    const result_str = c.zend_string_alloc(str.len, false);
    @memcpy(@as([*]u8, @ptrCast(&result_str.*.val))[0..str.len], str[0..]);
    @as([*]u8, @ptrCast(&result_str.*.val))[str.len] = 0;
    return .{ .inner = result_str };
}

pub fn from(zstr: *c.zend_string) String {
    return .{ .inner = zstr };
}

pub fn deinit(self: *String) void {
    c.zend_string_release(self.inner);
}

pub inline fn ptr(self: *const String) [*:0]const u8 {
    return @ptrCast(&self.inner.val);
}

pub inline fn len(self: *const String) usize {
    return self.inner.len;
}

pub fn slice(self: *const String) []const u8 {
    return self.ptr()[0..self.len()];
}

pub inline fn isEmpty(self: *const String) bool {
    return self.len() == 0;
}

pub fn concat(s1: []const u8, s2: []const u8) String {
    const result = c.zend_string_concat2(s1.ptr, s1.len, s2.ptr, s2.len);
    return .{ .inner = result };
}

pub fn concat3(s1: []const u8, s2: []const u8, s3: []const u8) String {
    const result = c.zend_string_concat3(
        s1.ptr,
        s1.len,
        s2.ptr,
        s2.len,
        s3.ptr,
        s3.len,
    );
    return .{ .inner = result };
}

pub fn toLower(self: *const String) String {
    const result = c.zend_string_tolower_ex(self.inner, false);
    return .{ .inner = result };
}

pub fn toUpper(self: *const String) String {
    const result = c.zend_string_toupper_ex(self.inner, false);
    return .{ .inner = result };
}

pub fn equals(self: *const String, other: *const String) bool {
    return c.zend_string_equal_val(self.inner, other.inner);
}

pub fn isAlphanumeric(self: *const String) bool {
    return c.zend_string_only_has_ascii_alphanumeric(self.inner);
}

pub fn hash(self: *const String) u64 {
    return c.zend_string_hash_func(self.inner);
}

pub inline fn refcount(self: *const String) u32 {
    return c.GC_REFCOUNT(@ptrCast(&self.inner.gc));
}

pub fn addref(self: *String) void {
    _ = c.GC_ADDREF(@ptrCast(&self.inner.gc));
}

pub fn delref(self: *String) u32 {
    return c.GC_DELREF(@ptrCast(&self.inner.gc));
}

pub inline fn isInterned(self: *const String) bool {
    return c.ZSTR_IS_INTERNED(self.inner) != 0;
}

const c = @import("../root.zig").c;
