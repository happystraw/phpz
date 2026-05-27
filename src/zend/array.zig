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
    pub fn init(capacity: u32) *Array {
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
    pub fn updateIndex(self: *Array, index: isize, value: *c.zval) ?*c.zval {
        return c.zend_hash_index_update(self.ptr(), @bitCast(index), value);
    }

    /// Add a new value by index (fails if index exists)
    pub fn addIndex(self: *Array, index: isize, value: *c.zval) ?*c.zval {
        return c.zend_hash_index_add(self.ptr(), @bitCast(index), value);
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
    pub fn findIndex(self: *Array, index: isize) ?*c.zval {
        return c.zend_hash_index_find(self.ptr(), @bitCast(index));
    }

    /// Check if a string key exists
    pub fn has(self: *Array, key: []const u8) bool {
        return self.find(key) != null;
    }

    /// Check if an index exists
    pub fn hasIndex(self: *Array, index: isize) bool {
        return self.findIndex(index) != null;
    }

    /// Delete a value by string key
    pub fn delete(self: *Array, key: []const u8) Error!void {
        if (c.zend_hash_str_del(self.ptr(), key.ptr, key.len) != c.SUCCESS) {
            return Error.NotFound;
        }
    }

    /// Delete a value by index
    pub fn deleteIndex(self: *Array, index: isize) Error!void {
        if (c.zend_hash_index_del(self.ptr(), @bitCast(index)) != c.SUCCESS) {
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
    pub fn compare(self: *Array, other: *Array, ordered: bool) c_int {
        return c.zend_hash_compare(self.ptr(), other.ptr(), null, ordered);
    }

    /// HashTable apply result codes.
    pub const ApplyResult = enum(c_int) {
        keep = c.ZEND_HASH_APPLY_KEEP,
        remove = c.ZEND_HASH_APPLY_REMOVE,
        stop = c.ZEND_HASH_APPLY_STOP,
    };

    /// Apply a callback to each element in the array.
    ///
    /// Return `.keep` to retain the element, `.remove` to delete it from the array,
    /// or `.stop` to halt iteration. Use `.remove` for filtering.
    pub fn applyEach(self: *Array, comptime apply_fn: fn (*c.zval) ApplyResult) void {
        const Cb = struct {
            fn cb(zv: *c.zval) callconv(.c) c_int {
                return @intFromEnum(apply_fn(zv));
            }
        };
        c.zend_hash_apply(self.ptr(), Cb.cb);
    }

    /// Apply a callback to each element, passing a user-provided argument pointer.
    pub fn applyEachWithArg(self: *Array, comptime apply_fn: fn (*c.zval, *anyopaque) ApplyResult, arg: *anyopaque) void {
        const Cb = struct {
            fn cb(zv: *c.zval, a: *anyopaque) callconv(.c) c_int {
                return @intFromEnum(apply_fn(zv, a));
            }
        };
        c.zend_hash_apply_with_argument(self.ptr(), Cb.cb, arg);
    }

    /// Sort the array in-place with a custom compare function and optional renumbering.
    pub fn sort(self: *Array, comptime compare_fn: fn (*c.zval, *c.zval) c_int, renumber: bool) void {
        const Cb = struct {
            fn cb(a: *c.Bucket, b: *c.Bucket) callconv(.c) c_int {
                return compare_fn(&a.val, &b.val);
            }
        };
        c.zend_hash_sort(self.ptr(), Cb.cb, renumber);
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

    pub const Key = union(enum) {
        int: isize,
        string: []const u8,
    };

    pub const Entry = struct {
        key: Key,
        value: *c.zval,
    };

    pub const Iterator = extern struct {
        ht: *c.HashTable,
        pos: c.HashPosition,

        pub fn init(array: *Array) Iterator {
            var self = Iterator{
                .ht = array.ptr(),
                .pos = 0,
            };
            self.reset();
            return self;
        }

        /// Reset the internal pointer to the first element.
        pub fn reset(self: *Iterator) void {
            c.zend_hash_internal_pointer_reset_ex(self.ht, &self.pos);
        }

        /// Return the current key without advancing, or null if exhausted.
        pub fn currentKey(self: *Iterator) ?Key {
            return if (self.hasMore()) self.peekKey() else null;
        }

        /// Return the current value without advancing, or null if exhausted.
        pub fn currentValue(self: *Iterator) ?*c.zval {
            return if (self.hasMore()) self.peekValue() else null;
        }

        /// Return the current element (key + value) without advancing, or null if exhausted.
        pub fn current(self: *Iterator) ?Entry {
            return if (self.hasMore()) self.peek() else null;
        }

        /// Return the current element and advance, or null if exhausted.
        pub fn next(self: *Iterator) ?Entry {
            if (!self.hasMore()) return null;
            defer self.advance();
            return self.peek();
        }

        /// Move the internal pointer forward without returning a value.
        pub fn advance(self: *Iterator) void {
            _ = c.zend_hash_move_forward_ex(self.ht, &self.pos);
        }

        /// Unsafe: peek key + value without bounds check. Prefer `current()`.
        pub fn peek(self: *Iterator) Entry {
            return .{ .key = self.peekKey(), .value = self.peekValue() };
        }

        /// Unsafe: peek the current key without bounds check. Prefer `currentKey()`.
        pub fn peekKey(self: *Iterator) Key {
            var str_key: ?*c.zend_string = null;
            var num_key: c.zend_ulong = undefined;
            return switch (c.zend_hash_get_current_key_ex(self.ht, @ptrCast(&str_key), &num_key, &self.pos)) {
                c.HASH_KEY_IS_STRING => .{ .string = str_key.?.*.val()[0..str_key.?.*.len] },
                c.HASH_KEY_IS_LONG => .{ .int = @bitCast(num_key) },
                else => unreachable,
            };
        }

        /// Unsafe: peek the current value without bounds check. Prefer `currentValue()`.
        pub fn peekValue(self: *Iterator) *c.zval {
            return c.zend_hash_get_current_data_ex(self.ht, &self.pos).?;
        }

        inline fn hasMore(self: *Iterator) bool {
            return c.zend_hash_has_more_elements_ex(self.ht, &self.pos) == c.SUCCESS;
        }
    };

    pub const KeyIterator = extern struct {
        ht: *c.HashTable,
        pos: c.HashPosition,

        pub fn init(array: *Array) KeyIterator {
            var self = KeyIterator{
                .ht = array.ptr(),
                .pos = 0,
            };
            self.reset();
            return self;
        }

        /// Reset the iterator to the first element.
        pub fn reset(self: *KeyIterator) void {
            c.zend_hash_internal_pointer_reset_ex(self.ht, &self.pos);
        }

        /// Return the current key without advancing, or null if exhausted.
        pub fn current(self: *KeyIterator) ?Key {
            return if (self.hasMore()) self.peek() else null;
        }

        /// Return the current key and advance, or null if exhausted.
        pub fn next(self: *KeyIterator) ?Key {
            if (!self.hasMore()) return null;
            defer self.advance();
            return self.peek();
        }

        /// Move the internal pointer forward without returning a value.
        pub fn advance(self: *KeyIterator) void {
            _ = c.zend_hash_move_forward_ex(self.ht, &self.pos);
        }

        /// Unsafe: peek without bounds check. Prefer `current()`.
        pub fn peek(self: *KeyIterator) Key {
            var str_key: ?*c.zend_string = null;
            var num_key: c.zend_ulong = undefined;
            return switch (c.zend_hash_get_current_key_ex(self.ht, @ptrCast(&str_key), &num_key, &self.pos)) {
                c.HASH_KEY_IS_STRING => .{ .string = str_key.?.*.val()[0..str_key.?.*.len] },
                c.HASH_KEY_IS_LONG => .{ .int = @bitCast(num_key) },
                else => unreachable,
            };
        }

        inline fn hasMore(self: *KeyIterator) bool {
            return c.zend_hash_has_more_elements_ex(self.ht, &self.pos) == c.SUCCESS;
        }
    };

    pub const ValueIterator = extern struct {
        ht: *c.HashTable,
        pos: c.HashPosition,

        pub fn init(array: *Array) ValueIterator {
            var self = ValueIterator{
                .ht = array.ptr(),
                .pos = 0,
            };
            self.reset();
            return self;
        }

        /// Reset the iterator to the first element.
        pub fn reset(self: *ValueIterator) void {
            c.zend_hash_internal_pointer_reset_ex(self.ht, &self.pos);
        }

        /// Return the current value without advancing, or null if exhausted.
        pub fn current(self: *ValueIterator) ?*c.zval {
            return if (self.hasMore()) self.peek() else null;
        }

        /// Return the current value and advance, or null if exhausted.
        pub fn next(self: *ValueIterator) ?*c.zval {
            if (!self.hasMore()) return null;
            defer self.advance();
            return self.peek();
        }

        /// Move the internal pointer forward without returning a value.
        pub fn advance(self: *ValueIterator) void {
            _ = c.zend_hash_move_forward_ex(self.ht, &self.pos);
        }

        /// Unsafe: peek without bounds check. Prefer `current()`.
        pub fn peek(self: *ValueIterator) *c.zval {
            return c.zend_hash_get_current_data_ex(self.ht, &self.pos).?;
        }

        inline fn hasMore(self: *ValueIterator) bool {
            return c.zend_hash_has_more_elements_ex(self.ht, &self.pos) == c.SUCCESS;
        }
    };

    pub fn PtrValueIterator(comptime T: type) type {
        return extern struct {
            ht: *c.HashTable,
            pos: c.HashPosition,

            const Self = @This();

            /// Create an iterator over the HashTable.
            ///
            /// Returns typed pointers to HashTable elements of type T, cast from raw data pointers.
            pub fn init(array: *Array) Self {
                var self = Self{
                    .ht = array.ptr(),
                    .pos = 0,
                };
                self.reset();
                return self;
            }

            /// Reset the iterator to the first element.
            pub fn reset(self: *Self) void {
                c.zend_hash_internal_pointer_reset_ex(self.ht, &self.pos);
            }

            /// Return the current element as a typed pointer without advancing.
            pub fn current(self: *Self) ?*T {
                return if (self.hasMore()) self.peek() else null;
            }

            /// Return the current element and advance, or null when iteration is complete.
            pub fn next(self: *Self) ?*T {
                if (!self.hasMore()) return null;
                defer self.advance();
                return self.peek();
            }

            /// Move the internal pointer forward without returning a value.
            pub fn advance(self: *Self) void {
                _ = c.zend_hash_move_forward_ex(self.ht, &self.pos);
            }

            /// Unsafe: peek without bounds check. Prefer `current()`.
            pub fn peek(self: *Self) *T {
                const info = c.zend_hash_get_current_data_ptr_ex(self.ht, &self.pos).?;
                return @ptrCast(@alignCast(info));
            }

            inline fn hasMore(self: *Self) bool {
                return c.zend_hash_has_more_elements_ex(self.ht, &self.pos) == c.SUCCESS;
            }
        };
    }

    pub fn iterator(self: *Array) Iterator {
        return Iterator.init(self);
    }

    pub fn keyIterator(self: *Array) KeyIterator {
        return KeyIterator.init(self);
    }

    pub fn valueIterator(self: *Array) ValueIterator {
        return ValueIterator.init(self);
    }
};

test {
    @import("std").testing.refAllDecls(Array);
    @import("std").testing.refAllDecls(Array.Iterator);
    @import("std").testing.refAllDecls(Array.KeyIterator);
    @import("std").testing.refAllDecls(Array.ValueIterator);
    @import("std").testing.refAllDecls(Array.PtrValueIterator(struct {}));
}
