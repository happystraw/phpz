const c = @import("../root.zig").c;
const Zval = @import("../zval.zig").Zval;

pub const Array = opaque {
    pub const Error = error{
        NotFound,
    };

    /// Create an empty array.
    ///
    /// Ownership: caller owns the returned array; call `release()` when done.
    pub fn empty() *Array {
        return @ptrCast(c.zend_new_array(0));
    }

    /// Create an array with initial capacity.
    ///
    /// Ownership: caller owns the returned array; call `release()` when done.
    pub fn init(capacity: u32) *Array {
        return @ptrCast(c.zend_new_array(capacity));
    }

    /// Create array from an existing zend_array pointer.
    ///
    /// Ownership: borrowed wrapper; no refcount change. Use `addref()` if the
    /// wrapper must outlive the original owner.
    pub inline fn from(zarr: *c.zend_array) *Array {
        return @ptrCast(zarr);
    }

    /// Get the underlying zend_array pointer.
    ///
    /// Ownership: borrowed raw pointer.
    pub inline fn ptr(self: *Array) *c.zend_array {
        return @ptrCast(@alignCast(self));
    }

    /// Release one owned array reference (decrement refcount, destroy if zero).
    pub inline fn release(self: *Array) void {
        c.zend_array_release(self.ptr());
    }

    /// Unconditionally destroy the array, regardless of refcount.
    pub fn destroy(self: *Array) void {
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

    /// Duplicate the array.
    ///
    /// Ownership: caller owns the returned array; call `release()` when done.
    pub fn duplicate(self: *Array) *Array {
        return @ptrCast(c.zend_array_dup(self.ptr()));
    }

    /// Add or update a value by string key.
    ///
    /// Ownership: the array takes ownership of `value`'s zval contents. If
    /// `value` is borrowed and must remain independently owned, addref/copy it
    /// before calling. The returned pointer is borrowed from the array.
    pub fn update(self: *Array, key: []const u8, value: *c.zval) ?*c.zval {
        return c.zend_hash_str_update(self.ptr(), key.ptr, key.len, value);
    }

    /// Add a new value by string key (fails if key exists).
    ///
    /// Ownership: on success, the array takes ownership of `value`'s zval
    /// contents. The returned pointer is borrowed from the array.
    pub fn add(self: *Array, key: []const u8, value: *c.zval) ?*c.zval {
        return c.zend_hash_str_add(self.ptr(), key.ptr, key.len, value);
    }

    /// Add or update a value by index.
    ///
    /// Ownership: the array takes ownership of `value`'s zval contents. If
    /// `value` is borrowed and must remain independently owned, addref/copy it
    /// before calling. The returned pointer is borrowed from the array.
    pub fn updateIndex(self: *Array, index: isize, value: *c.zval) ?*c.zval {
        return c.zend_hash_index_update(self.ptr(), @bitCast(index), value);
    }

    /// Add a new value by index (fails if index exists).
    ///
    /// Ownership: on success, the array takes ownership of `value`'s zval
    /// contents. The returned pointer is borrowed from the array.
    pub fn addIndex(self: *Array, index: isize, value: *c.zval) ?*c.zval {
        return c.zend_hash_index_add(self.ptr(), @bitCast(index), value);
    }

    /// Append a value to the array (next index).
    ///
    /// Ownership: on success, the array takes ownership of `value`'s zval
    /// contents. The returned pointer is borrowed from the array.
    pub fn append(self: *Array, value: *c.zval) ?*c.zval {
        return c.zend_hash_next_index_insert(self.ptr(), value);
    }

    /// Find a value by string key.
    ///
    /// Ownership: borrowed zval pointer owned by the array; addref/copy before
    /// storing it beyond the array or mutating the table.
    pub fn find(self: *Array, key: []const u8) ?*c.zval {
        return c.zend_hash_str_find(self.ptr(), key.ptr, key.len);
    }

    /// Find a pointer stored under a string key.
    ///
    /// Ownership: borrowed pointer owned by the array.
    pub fn findPtr(self: *Array, comptime T: type, key: []const u8) ?*T {
        const value = c.zend_hash_str_find_ptr(self.ptr(), key.ptr, key.len);
        return if (value != null) @ptrCast(@alignCast(value)) else null;
    }

    /// Find a value by index.
    ///
    /// Ownership: borrowed zval pointer owned by the array; addref/copy before
    /// storing it beyond the array or mutating the table.
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

    /// Copy from source array.
    ///
    /// Ownership: copied elements are shared according to Zend hash copy
    /// semantics; addref values first if independent ownership is required.
    pub fn copy(self: *Array, source: *Array) void {
        c.zend_hash_copy(self.ptr(), source.ptr(), null);
    }

    /// Merge from source array.
    ///
    /// Ownership: merged elements are shared according to Zend hash merge
    /// semantics; addref values first if independent ownership is required.
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
    pub fn applyEach(self: *Array, apply_fn: fn (*c.zval) ApplyResult) void {
        const Cb = struct {
            fn cb(zv: ?*c.zval) callconv(.c) c_int {
                return @backingInt(apply_fn(zv.?));
            }
        };
        c.zend_hash_apply(self.ptr(), Cb.cb);
    }

    /// Apply a callback to each element, passing a user-provided argument pointer.
    pub fn applyEachWithArg(
        self: *Array,
        comptime ArgType: type,
        apply_fn: fn (*c.zval, *ArgType) ApplyResult,
        arg: *ArgType,
    ) void {
        const Cb = struct {
            fn cb(zv: ?*c.zval, a: ?*anyopaque) callconv(.c) c_int {
                return @backingInt(apply_fn(zv.?, @ptrCast(@alignCast(a.?))));
            }
        };
        c.zend_hash_apply_with_argument(self.ptr(), Cb.cb, arg);
    }

    pub const SortOrder = enum(c_int) { less = -1, equal = 0, greater = 1 };

    /// Sort the array in-place with a custom compare function and optional renumbering.
    pub fn sort(self: *Array, compare_fn: fn (*c.Bucket, *c.Bucket) SortOrder, renumber: bool) void {
        const Cb = struct {
            fn cb(a: ?*c.Bucket, b: ?*c.Bucket) callconv(.c) c_int {
                return @backingInt(compare_fn(a.?, b.?));
            }
        };
        c.zend_hash_sort(self.ptr(), Cb.cb, renumber);
    }

    /// Get refcount
    pub inline fn refcount(self: *Array) u32 {
        return c.zend_gc_refcount(&self.ptr().gc);
    }

    /// Increment refcount.
    ///
    /// Ownership: caller owns the added reference and must release/delref it.
    pub fn addref(self: *Array) void {
        _ = c.zend_gc_addref(&self.ptr().gc);
    }

    /// Decrement refcount.
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
        /// Ownership: borrowed key view owned by the array bucket.
        key: Key,
        /// Ownership: borrowed zval pointer owned by the array bucket.
        value: *c.zval,
    };

    /// Iterate values with a comptime callback — IS_UNDEF and user code in same scope.
    ///
    /// Ownership: callback values are borrowed from the array.
    ///
    /// Equivalent to C's `ZEND_HASH_FOREACH_VAL`.
    /// Unlike pull-based iterators, this inlines the loop body so the compiler can
    /// eliminate redundant type checks (e.g., IS_UNDEF + IS_LONG in the same scope).
    ///
    /// Example:
    /// ```zig
    /// var sum: i64 = 0;
    /// arr.eachValue(&sum, struct {
    ///     fn body(zv: *c.zval, s: *i64) void {
    ///         if (Zval.raw.is(zv, .int)) s.* += Zval.raw.asUnchecked(zv, .int);
    ///     }
    /// }.body);
    /// ```
    pub inline fn eachValue(
        self: *Array,
        ctx: anytype,
        comptime body: if (@TypeOf(ctx) == void) fn (*c.zval) void else fn (*c.zval, @TypeOf(ctx)) void,
    ) void {
        const ht = self.ptr();
        const count = ht.nNumUsed;
        const stride: usize = c.ZEND_HASH_ELEMENT_SIZE(ht);
        var cursor: [*]u8 = @ptrCast(c.phpz_hash_table_get_ar_packed(ht));

        var i: u32 = 0;
        while (i < count) : (i += 1) {
            const zv: *c.zval = @ptrCast(@alignCast(cursor));
            cursor += stride;

            // IS_UNDEF check in same scope as body → compiler can eliminate redundancy
            if (Zval.raw.is(zv, .undef)) {
                @branchHint(.unlikely);
                continue;
            }
            if (comptime @TypeOf(ctx) == void) {
                @call(.always_inline, body, .{zv});
            } else {
                @call(.always_inline, body, .{ zv, ctx });
            }
        }
    }

    /// Iterate key-value pairs with a comptime callback — IS_UNDEF and user code in same scope.
    ///
    /// Ownership: callback entries contain borrowed keys and values from the array.
    ///
    /// Equivalent to C's `ZEND_HASH_FOREACH`. Walks the bucket array directly.
    /// Key extraction follows C semantics (before IS_UNDEF check).
    /// The callback receives an `Entry` (`.key` and `.value`).
    /// When `ctx` is `void`, no context argument is passed.
    ///
    /// Example:
    /// ```zig
    /// arr.each(&ctx, struct {
    ///     fn body(e: Array.Entry, ctx: *Ctx) void {
    ///         switch (e.key) {
    ///             .int => |i| // numeric key
    ///             .string => |s| // string key
    ///         }
    ///     }
    /// }.body);
    /// ```
    pub inline fn each(
        self: *Array,
        ctx: anytype,
        comptime body: if (@TypeOf(ctx) == void) fn (Entry) void else fn (Entry, @TypeOf(ctx)) void,
    ) void {
        const ht = self.ptr();
        const count = ht.nNumUsed;
        const is_packed = (ht.u.flags & c.HASH_FLAG_PACKED) != 0;
        const stride: usize = c.ZEND_HASH_ELEMENT_SIZE(ht);
        var cursor: [*]u8 = @ptrCast(c.phpz_hash_table_get_ar_packed(ht));

        if (is_packed) {
            // Packed
            var idx: u32 = 0;
            var i: u32 = 0;
            while (i < count) : (i += 1) {
                const zv: *c.zval = @ptrCast(@alignCast(cursor));
                cursor += stride;
                const key: Key = .{ .int = @as(isize, @intCast(idx)) };
                idx += 1;
                if (Zval.raw.is(zv, .undef)) {
                    @branchHint(.unlikely);
                    continue; // IS_UNDEF check
                }
                if (comptime @TypeOf(ctx) == void) {
                    @call(.always_inline, body, .{Entry{ .key = key, .value = zv }});
                } else {
                    @call(.always_inline, body, .{ Entry{ .key = key, .value = zv }, ctx });
                }
            }
        } else {
            // Hash
            var i: u32 = 0;
            while (i < count) : (i += 1) {
                const bucket: *c.Bucket = @ptrCast(@alignCast(cursor));
                const zv: *c.zval = &bucket.val;
                cursor += stride;
                const key: Key = if (bucket.key) |k|
                    .{ .string = k.*.val()[0..k.*.len] }
                else
                    .{ .int = @bitCast(bucket.h) };
                if (Zval.raw.is(zv, .undef)) {
                    @branchHint(.unlikely);
                    continue; // IS_UNDEF check
                }
                if (comptime @TypeOf(ctx) == void) {
                    @call(.always_inline, body, .{Entry{ .key = key, .value = zv }});
                } else {
                    @call(.always_inline, body, .{ Entry{ .key = key, .value = zv }, ctx });
                }
            }
        }
    }

    pub const Iterator = struct {
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
        ///
        /// Ownership: borrowed key view owned by the array.
        pub fn currentKey(self: *Iterator) ?Key {
            return if (self.hasMore()) self.peekKey() else null;
        }

        /// Return the current value without advancing, or null if exhausted.
        ///
        /// Ownership: borrowed zval pointer owned by the array.
        pub fn currentValue(self: *Iterator) ?*c.zval {
            return if (self.hasMore()) self.peekValue() else null;
        }

        /// Return the current element (key + value) without advancing, or null if exhausted.
        ///
        /// Ownership: borrowed key/value owned by the array.
        pub fn current(self: *Iterator) ?Entry {
            return if (self.hasMore()) self.peek() else null;
        }

        /// Return the current element and advance, or null if exhausted.
        ///
        /// Ownership: borrowed key/value owned by the array.
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
        ///
        /// Ownership: borrowed key/value owned by the array.
        pub fn peek(self: *Iterator) Entry {
            return .{ .key = self.peekKey(), .value = self.peekValue() };
        }

        /// Unsafe: peek the current key without bounds check. Prefer `currentKey()`.
        ///
        /// Ownership: borrowed key view owned by the array.
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
        ///
        /// Ownership: borrowed zval pointer owned by the array.
        pub fn peekValue(self: *Iterator) *c.zval {
            return c.zend_hash_get_current_data_ex(self.ht, &self.pos).?;
        }

        inline fn hasMore(self: *Iterator) bool {
            return c.zend_hash_has_more_elements_ex(self.ht, &self.pos) == c.SUCCESS;
        }
    };

    pub const KeyIterator = struct {
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
        ///
        /// Ownership: borrowed key view owned by the array.
        pub fn current(self: *KeyIterator) ?Key {
            return if (self.hasMore()) self.peek() else null;
        }

        /// Return the current key and advance, or null if exhausted.
        ///
        /// Ownership: borrowed key view owned by the array.
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
        ///
        /// Ownership: borrowed key view owned by the array.
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

    pub const ValueIterator = struct {
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
        ///
        /// Ownership: borrowed zval pointer owned by the array.
        pub fn current(self: *ValueIterator) ?*c.zval {
            return if (self.hasMore()) self.peek() else null;
        }

        /// Return the current value and advance, or null if exhausted.
        ///
        /// Ownership: borrowed zval pointer owned by the array.
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
        ///
        /// Ownership: borrowed zval pointer owned by the array.
        pub fn peek(self: *ValueIterator) *c.zval {
            return c.zend_hash_get_current_data_ex(self.ht, &self.pos).?;
        }

        inline fn hasMore(self: *ValueIterator) bool {
            return c.zend_hash_has_more_elements_ex(self.ht, &self.pos) == c.SUCCESS;
        }
    };

    /// Fast value-only iterator that walks the raw HashTable element storage directly.
    /// Zero C function calls — same performance as `eachValue`.
    /// Automatically skips IS_UNDEF slots.
    /// Do not structurally modify the HashTable while this iterator is in use.
    pub const FastValueIterator = struct {
        cursor: [*]u8,
        stride: usize,
        pos: u32,
        count: u32,

        /// Create an iterator over the array.
        pub fn init(array: *Array) FastValueIterator {
            const ht = array.ptr();
            return .{
                .cursor = @ptrCast(c.phpz_hash_table_get_ar_packed(ht)),
                .stride = c.ZEND_HASH_ELEMENT_SIZE(ht),
                .pos = 0,
                .count = ht.nNumUsed,
            };
        }

        /// Reset to the beginning of the array.
        pub fn reset(self: *FastValueIterator) void {
            self.cursor = @ptrCast(self.cursor - self.pos * self.stride);
            self.pos = 0;
        }

        /// Return the current value and advance, or null when exhausted.
        ///
        /// Ownership: borrowed zval pointer owned by the array.
        /// Automatically skips IS_UNDEF slots.
        pub inline fn next(self: *FastValueIterator) ?*c.zval {
            while (self.pos < self.count) {
                const zv: *c.zval = @ptrCast(@alignCast(self.cursor));
                self.cursor += self.stride;
                self.pos += 1;
                if (Zval.raw.is(zv, .undef)) {
                    @branchHint(.unlikely);
                    continue;
                }
                return zv;
            }
            return null;
        }

        /// Return the current value without advancing, or null if exhausted.
        ///
        /// Ownership: borrowed zval pointer owned by the array.
        pub fn current(self: *FastValueIterator) ?*c.zval {
            var p = self.pos;
            var cursor = self.cursor;
            while (p < self.count) {
                const zv: *c.zval = @ptrCast(@alignCast(cursor));
                cursor += self.stride;
                p += 1;
                if (Zval.raw.is(zv, .undef)) {
                    @branchHint(.unlikely);
                    continue;
                }
                return zv;
            }
            return null;
        }
    };

    /// Fast key+value iterator that walks the raw HashTable element storage directly.
    /// Zero C function calls — same performance as `each`.
    /// Extracts keys inline and automatically skips IS_UNDEF slots.
    /// Do not structurally modify the HashTable while this iterator is in use.
    pub const FastIterator = struct {
        cursor: [*]u8,
        stride: usize,
        pos: u32,
        count: u32,
        idx: u32,
        is_packed: bool,

        /// Create an iterator over the array.
        pub fn init(array: *Array) FastIterator {
            const ht = array.ptr();
            return .{
                .cursor = @ptrCast(c.phpz_hash_table_get_ar_packed(ht)),
                .stride = c.ZEND_HASH_ELEMENT_SIZE(ht),
                .pos = 0,
                .count = ht.nNumUsed,
                .idx = 0,
                .is_packed = (ht.u.flags & c.HASH_FLAG_PACKED) != 0,
            };
        }

        /// Reset to the beginning of the array.
        pub fn reset(self: *FastIterator) void {
            self.cursor = @ptrCast(self.cursor - self.pos * self.stride);
            self.pos = 0;
            self.idx = 0;
        }

        /// Return the current entry (key + value) and advance, or null when exhausted.
        ///
        /// Ownership: borrowed key/value owned by the array.
        /// Automatically skips IS_UNDEF slots.
        pub inline fn next(self: *FastIterator) ?Entry {
            if (self.is_packed) {
                while (self.pos < self.count) {
                    const zv: *c.zval = @ptrCast(@alignCast(self.cursor));
                    self.cursor += self.stride;
                    self.pos += 1;
                    const key: Key = .{ .int = @as(isize, @intCast(self.idx)) };
                    self.idx += 1;
                    if (Zval.raw.is(zv, .undef)) {
                        @branchHint(.unlikely);
                        continue;
                    }
                    return Entry{ .key = key, .value = zv };
                }
            } else {
                while (self.pos < self.count) {
                    const bucket: *c.Bucket = @ptrCast(@alignCast(self.cursor));
                    const zv: *c.zval = &bucket.val;
                    self.cursor += self.stride;
                    self.pos += 1;
                    const key: Key = if (bucket.key) |k|
                        .{ .string = k.*.val()[0..k.*.len] }
                    else
                        .{ .int = @bitCast(bucket.h) };
                    if (Zval.raw.is(zv, .undef)) {
                        @branchHint(.unlikely);
                        continue;
                    }
                    return Entry{ .key = key, .value = zv };
                }
            }
            return null;
        }

        /// Return the current entry without advancing, or null if exhausted.
        ///
        /// Ownership: borrowed key/value owned by the array.
        pub fn current(self: *FastIterator) ?Entry {
            var p = self.pos;
            var cursor = self.cursor;
            var i = self.idx;
            if (self.is_packed) {
                while (p < self.count) {
                    const zv: *c.zval = @ptrCast(@alignCast(cursor));
                    cursor += self.stride;
                    p += 1;
                    const key: Key = .{ .int = @as(isize, @intCast(i)) };
                    i += 1;
                    if (Zval.raw.is(zv, .undef)) {
                        @branchHint(.unlikely);
                        continue;
                    }
                    return Entry{ .key = key, .value = zv };
                }
            } else {
                while (p < self.count) {
                    const bucket: *c.Bucket = @ptrCast(@alignCast(cursor));
                    const zv: *c.zval = &bucket.val;
                    cursor += self.stride;
                    p += 1;
                    const key: Key = if (bucket.key) |k|
                        .{ .string = k.*.val()[0..k.*.len] }
                    else
                        .{ .int = @bitCast(bucket.h) };
                    if (Zval.raw.is(zv, .undef)) {
                        @branchHint(.unlikely);
                        continue;
                    }
                    return Entry{ .key = key, .value = zv };
                }
            }
            return null;
        }
    };

    pub fn PtrValueIterator(comptime T: type) type {
        return struct {
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
            ///
            /// Ownership: borrowed pointer owned by the array.
            pub fn current(self: *Self) ?*T {
                return if (self.hasMore()) self.peek() else null;
            }

            /// Return the current element and advance, or null when iteration is complete.
            ///
            /// Ownership: borrowed pointer owned by the array.
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
            ///
            /// Ownership: borrowed pointer owned by the array.
            pub fn peek(self: *Self) *T {
                const info = c.zend_hash_get_current_data_ptr_ex(self.ht, &self.pos).?;
                return @ptrCast(@alignCast(info));
            }

            inline fn hasMore(self: *Self) bool {
                return c.zend_hash_has_more_elements_ex(self.ht, &self.pos) == c.SUCCESS;
            }
        };
    }

    /// Create a C-API iterator (key + value). Prefer `fastIterator` for read-only access.
    pub fn iterator(self: *Array) Iterator {
        return Iterator.init(self);
    }

    /// Create a C-API key-only iterator.
    pub fn keyIterator(self: *Array) KeyIterator {
        return KeyIterator.init(self);
    }

    /// Create a C-API value-only iterator.
    pub fn valueIterator(self: *Array) ValueIterator {
        return ValueIterator.init(self);
    }

    /// Create a fast key+value iterator that walks the raw HashTable element storage.
    /// Zero C function calls — same performance as `each`.
    pub fn fastIterator(self: *Array) FastIterator {
        return FastIterator.init(self);
    }

    /// Create a fast value-only iterator that walks the raw HashTable element storage.
    /// Zero C function calls — same performance as `eachValue`.
    pub fn fastValueIterator(self: *Array) FastValueIterator {
        return FastValueIterator.init(self);
    }
};

test {
    @import("std").testing.refAllDecls(Array);
    @import("std").testing.refAllDecls(Array.Iterator);
    @import("std").testing.refAllDecls(Array.KeyIterator);
    @import("std").testing.refAllDecls(Array.ValueIterator);
    @import("std").testing.refAllDecls(Array.FastIterator);
    @import("std").testing.refAllDecls(Array.FastValueIterator);
    @import("std").testing.refAllDecls(Array.PtrValueIterator(struct {}));
}
