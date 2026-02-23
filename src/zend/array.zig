const c = @import("../root.zig").c;

pub const Array = opaque {
    pub const Error = error{
        NotFound,
    };

    /// Create an empty array
    pub fn empty() *Array {
        return @ptrCast(c.zend_new_array(0));
    }

    /// Create an array with initial capacity
    pub fn init(capacity: usize) *Array {
        return @ptrCast(c.zend_new_array(capacity));
    }

    /// Create array from an existing zend_array pointer
    pub inline fn from(zarr: *c.zend_array) *Array {
        return @ptrCast(zarr);
    }

    /// Get the underlying zend_array pointer
    pub inline fn ptr(self: *Array) *c.zend_array {
        return @ptrCast(@alignCast(self));
    }

    /// Destroy the array
    pub fn deinit(self: *Array) void {
        c.zend_array_destroy(self.ptr());
    }

    /// Get the number of elements
    pub inline fn len(self: *Array) usize {
        return @intCast(self.ptr().nNumOfElements);
    }

    /// Check if array is empty
    pub inline fn isEmpty(self: *Array) bool {
        return self.len() == 0;
    }

    /// Clear all elements
    pub fn clear(self: *Array) void {
        c.zend_hash_clean(self.ptr());
    }

    /// Duplicate the array
    pub fn duplicate(self: *Array) *Array {
        return @ptrCast(c.zend_array_dup(self.ptr()));
    }

    /// Add or update a value by string key
    pub fn update(self: *Array, key: []const u8, value: *c.zval) ?*c.zval {
        return c.zend_hash_str_update(self.ptr(), key.ptr, key.len, value);
    }

    /// Add a new value by string key (fails if key exists)
    pub fn add(self: *Array, key: []const u8, value: *c.zval) ?*c.zval {
        return c.zend_hash_str_add(self.ptr(), key.ptr, key.len, value);
    }

    /// Add or update a value by index
    pub fn updateIndex(self: *Array, index: usize, value: *c.zval) ?*c.zval {
        return c.zend_hash_index_update(self.ptr(), @intCast(index), value);
    }

    /// Add a new value by index (fails if index exists)
    pub fn addIndex(self: *Array, index: usize, value: *c.zval) ?*c.zval {
        return c.zend_hash_index_add(self.ptr(), @intCast(index), value);
    }

    /// Append a value to the array (next index)
    pub fn append(self: *Array, value: *c.zval) ?*c.zval {
        return c.zend_hash_next_index_insert(self.ptr(), value);
    }

    /// Find a value by string key
    pub fn find(self: *Array, key: []const u8) ?*c.zval {
        return c.zend_hash_str_find(self.ptr(), key.ptr, key.len);
    }

    /// Find a value by index
    pub fn findIndex(self: *Array, index: usize) ?*c.zval {
        return c.zend_hash_index_find(self.ptr(), @intCast(index));
    }

    /// Check if a string key exists
    pub fn has(self: *Array, key: []const u8) bool {
        return self.find(key) != null;
    }

    /// Check if an index exists
    pub fn hasIndex(self: *Array, index: usize) bool {
        return self.findIndex(index) != null;
    }

    /// Delete a value by string key
    pub fn delete(self: *Array, key: []const u8) Error!void {
        if (c.zend_hash_str_del(self.ptr(), key.ptr, key.len) != c.SUCCESS) {
            return Error.NotFound;
        }
    }

    /// Delete a value by index
    pub fn deleteIndex(self: *Array, index: usize) Error!void {
        if (c.zend_hash_index_del(self.ptr(), @intCast(index)) != c.SUCCESS) {
            return Error.NotFound;
        }
    }

    /// Rehash the array (reindex)
    pub fn rehash(self: *Array) void {
        c.zend_hash_rehash(self.ptr());
    }

    /// Copy from source array
    pub fn copy(self: *Array, source: *Array) void {
        c.zend_hash_copy(self.ptr(), source.ptr(), null);
    }

    /// Merge from source array
    pub fn merge(self: *Array, source: *Array, overwrite: bool) void {
        c.zend_hash_merge(self.ptr(), source.ptr(), null, overwrite);
    }

    /// Compare two arrays
    pub fn compare(self: *Array, other: *const Array, ordered: bool) c_int {
        return c.zend_hash_compare(self.ptr(), other.ptr(), null, ordered);
    }

    /// Get refcount
    pub inline fn refcount(self: *Array) u32 {
        return c.zend_gc_refcount(&self.ptr().gc);
    }

    /// Increment refcount
    pub fn addref(self: *Array) void {
        _ = c.zend_gc_addref(&self.ptr().gc);
    }

    /// Decrement refcount
    pub fn delref(self: *Array) void {
        _ = c.zend_gc_delref(&self.ptr().gc);
    }

    /// Check if array is immutable
    pub inline fn isImmutable(self: *Array) bool {
        return (c.GC_FLAGS(self.ptr()) & c.GC_IMMUTABLE) != 0;
    }
};
