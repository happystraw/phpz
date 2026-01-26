const Array = @This();

inner: *c.HashTable,

pub const Error = error{
    NotFound,
};

/// Create an empty array
pub fn empty() Array {
    return .{ .inner = c.zend_new_array(0) };
}

/// Create an array with initial capacity
pub fn init(capacity: usize) Array {
    return .{ .inner = c.zend_new_array(capacity) };
}

/// Create array from an existing HashTable pointer
pub fn from(ht: *c.HashTable) Array {
    return .{ .inner = ht };
}

/// Destroy the array
pub fn deinit(self: *Array) void {
    c.zend_array_destroy(self.inner);
}

/// Get the number of elements
pub inline fn len(self: *const Array) usize {
    return @intCast(self.inner.nNumOfElements);
}

/// Check if array is empty
pub inline fn isEmpty(self: *const Array) bool {
    return self.len() == 0;
}

/// Clear all elements
pub fn clear(self: *Array) void {
    c.zend_hash_clean(self.inner);
}

/// Duplicate the array
pub fn duplicate(self: *const Array) Array {
    return .{ .inner = c.zend_array_dup(self.inner) };
}

/// Add or update a value by string key
pub fn update(self: *Array, key: []const u8, value: *c.zval) ?*c.zval {
    return c.zend_hash_str_update(self.inner, key.ptr, key.len, value);
}

/// Add a new value by string key (fails if key exists)
pub fn add(self: *Array, key: []const u8, value: *c.zval) ?*c.zval {
    return c.zend_hash_str_add(self.inner, key.ptr, key.len, value);
}

/// Add or update a value by index
pub fn updateIndex(self: *Array, index: usize, value: *c.zval) ?*c.zval {
    return c.zend_hash_index_update(self.inner, @intCast(index), value);
}

/// Add a new value by index (fails if index exists)
pub fn addIndex(self: *Array, index: usize, value: *c.zval) ?*c.zval {
    return c.zend_hash_index_add(self.inner, @intCast(index), value);
}

/// Append a value to the array (next index)
pub fn append(self: *Array, value: *c.zval) ?*c.zval {
    return c.zend_hash_next_index_insert(self.inner, value);
}

/// Find a value by string key
pub fn find(self: *const Array, key: []const u8) ?*c.zval {
    return c.zend_hash_str_find(self.inner, key.ptr, key.len);
}

/// Find a value by index
pub fn findIndex(self: *const Array, index: usize) ?*c.zval {
    return c.zend_hash_index_find(self.inner, @intCast(index));
}

/// Check if a string key exists
pub fn has(self: *const Array, key: []const u8) bool {
    return self.find(key) != null;
}

/// Check if an index exists
pub fn hasIndex(self: *const Array, index: usize) bool {
    return self.findIndex(index) != null;
}

/// Delete a value by string key
pub fn delete(self: *Array, key: []const u8) Error!void {
    if (c.zend_hash_str_del(self.inner, key.ptr, key.len) != c.SUCCESS) {
        return Error.NotFound;
    }
}

/// Delete a value by index
pub fn deleteIndex(self: *Array, index: usize) Error!void {
    if (c.zend_hash_index_del(self.inner, @intCast(index)) != c.SUCCESS) {
        return Error.NotFound;
    }
}

/// Rehash the array (reindex)
pub fn rehash(self: *Array) void {
    c.zend_hash_rehash(self.inner);
}

/// Copy from source array
pub fn copy(self: *Array, source: *const Array) void {
    c.zend_hash_copy(self.inner, source.inner, null);
}

/// Merge from source array
pub fn merge(self: *Array, source: *const Array, overwrite: bool) void {
    c.zend_hash_merge(self.inner, source.inner, null, overwrite);
}

/// Compare two arrays
pub fn compare(self: *const Array, other: *const Array, ordered: bool) c_int {
    return c.zend_hash_compare(self.inner, other.inner, null, ordered);
}

/// Get refcount
pub inline fn refcount(self: *const Array) u32 {
    return c.zend_gc_refcount(&self.inner.gc);
}

/// Increment refcount
pub fn addref(self: *Array) void {
    _ = c.zend_gc_addref(&self.inner.gc);
}

/// Decrement refcount
pub fn delref(self: *Array) void {
    _ = c.zend_gc_delref(&self.inner.gc);
}

/// Check if array is immutable
pub inline fn isImmutable(self: *const Array) bool {
    return (c.GC_FLAGS(self.inner) & c.GC_IMMUTABLE) != 0;
}

const c = @import("../root.zig").c;
