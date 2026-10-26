const std = @import("std");
const c = @import("../root.zig").c;
const exception = @import("../exception.zig");
const Zval = @import("../zval.zig").Zval;
const String = @import("string.zig").String;

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

    /// Check for consecutive integer keys from zero, in iteration order.
    /// Empty arrays are lists.
    pub fn isList(self: *Array) bool {
        return c.zend_array_is_list(self.ptr());
    }

    /// Grow capacity without changing elements; never shrinks.
    /// Preserves packed/mixed layout; initializes unused storage as mixed.
    /// Requires mutable, uniquely owned storage; may invalidate entry pointers/iterators.
    pub fn extend(self: *Array, capacity: u32) void {
        c.zend_hash_extend(self.ptr(), capacity, (self.ptr().u.flags & c.HASH_FLAG_PACKED) != 0);
    }

    /// Clear all elements
    pub fn clear(self: *Array) void {
        c.zend_hash_clean(self.ptr());
    }

    /// Duplicate the array.
    ///
    /// Ownership: caller owns the returned array; call `release()` when done.
    pub fn dupe(self: *Array) *Array {
        return @ptrCast(c.zend_array_dup(self.ptr()));
    }

    /// Shallow-copy values into an owned list with keys starting at zero.
    /// Unwraps single-owner PHP references. Source is borrowed; release() the result.
    pub fn toList(self: *Array) *Array {
        return @ptrCast(c.zend_array_to_list(self.ptr()));
    }

    /// Add or update a value by raw string key. Numeric strings stay string keys,
    /// unlike PHP's `$array["1"]`; use symtableUpdate() for PHP key semantics.
    ///
    /// Ownership: the array takes ownership of `value`'s zval contents. If
    /// `value` is borrowed and must remain independently owned, addref/copy it
    /// before calling. The returned pointer is borrowed from the array.
    pub fn update(self: *Array, key: []const u8, value: *c.zval) *c.zval {
        return c.zend_hash_str_update(self.ptr(), key.ptr, key.len, value).?;
    }

    /// Add a new value by string key (fails if key exists).
    ///
    /// Ownership: on success, the array takes ownership of `value`'s zval
    /// contents. The returned pointer is borrowed from the array.
    pub fn add(self: *Array, key: []const u8, value: *c.zval) ?*c.zval {
        return c.zend_hash_str_add(self.ptr(), key.ptr, key.len, value);
    }

    /// Like update(), with a borrowed Zend string key retained on insertion.
    /// No numeric-string conversion. Requires mutable, uniquely owned storage.
    pub fn updateStr(self: *Array, key: *String, value: *c.zval) *c.zval {
        return c.zend_hash_update(self.ptr(), key.ptr(), value).?;
    }

    /// Like updateStr(), but returns null if the key exists and leaves value owned
    /// by the caller. On success, transfers value contents and returns a borrowed slot.
    pub fn addStr(self: *Array, key: *String, value: *c.zval) ?*c.zval {
        return c.zend_hash_add(self.ptr(), key.ptr(), value);
    }

    /// Add or update a value by index.
    ///
    /// Ownership: the array takes ownership of `value`'s zval contents. If
    /// `value` is borrowed and must remain independently owned, addref/copy it
    /// before calling. The returned pointer is borrowed from the array.
    pub fn updateIndex(self: *Array, index: isize, value: *c.zval) *c.zval {
        return c.zend_hash_index_update(self.ptr(), @bitCast(index), value).?;
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

    /// Store and return an IS_PTR by string key, without retaining its pointee.
    /// Keep the pointee alive; empty()/init() tables do not free it, while wrapped
    /// tables use their configured destructor. Requires a mutable, uniquely owned
    /// internal table; do not expose IS_PTR values to PHP.
    pub fn updatePtr(self: *Array, comptime T: type, key: []const u8, value: *T) *T {
        return @ptrCast(@alignCast(c.zend_hash_str_update_ptr(self.ptr(), key.ptr, key.len, value).?));
    }

    /// Like updatePtr(), but returns null without changes if the key exists.
    pub fn addPtr(self: *Array, comptime T: type, key: []const u8, value: *T) ?*T {
        const result = c.zend_hash_str_add_ptr(self.ptr(), key.ptr, key.len, value);
        return if (result != null) @ptrCast(@alignCast(result)) else null;
    }

    /// Like updatePtr(), with a Zend string key retained on insertion.
    pub fn updateStrPtr(self: *Array, comptime T: type, key: *String, value: *T) *T {
        return @ptrCast(@alignCast(c.zend_hash_update_ptr(self.ptr(), key.ptr(), value).?));
    }

    /// Like addPtr(), with a Zend string key retained on insertion.
    pub fn addStrPtr(self: *Array, comptime T: type, key: *String, value: *T) ?*T {
        const result = c.zend_hash_add_ptr(self.ptr(), key.ptr(), value);
        return if (result != null) @ptrCast(@alignCast(result)) else null;
    }

    /// Like updatePtr(), keyed by index.
    pub fn updateIndexPtr(self: *Array, comptime T: type, index: isize, value: *T) *T {
        return @ptrCast(@alignCast(c.phpz_hash_index_update_ptr(self.ptr(), @bitCast(index), value).?));
    }

    /// Like addPtr(), keyed by index.
    pub fn addIndexPtr(self: *Array, comptime T: type, index: isize, value: *T) ?*T {
        const result = c.zend_hash_index_add_ptr(self.ptr(), @bitCast(index), value);
        return if (result != null) @ptrCast(@alignCast(result)) else null;
    }

    /// Append an internal pointer at the next index; returns null on failure.
    /// Ownership and table requirements follow updatePtr().
    pub fn appendPtr(self: *Array, comptime T: type, value: *T) ?*T {
        const result = c.zend_hash_next_index_insert_ptr(self.ptr(), value);
        return if (result != null) @ptrCast(@alignCast(result)) else null;
    }

    /// Find a value by raw string key. "1" does not match the integer key 1 that
    /// PHP stores for `$array["1"]`; use symtableFind() for PHP key semantics.
    ///
    /// Ownership: borrowed zval pointer owned by the array; addref/copy before
    /// storing it beyond the array or mutating the table.
    pub fn find(self: *Array, key: []const u8) ?*c.zval {
        return c.zend_hash_str_find(self.ptr(), key.ptr, key.len);
    }

    /// Find a value like PHP's `$array[$key]`: canonical integer strings such as
    /// "42" or "-1" address integer keys. Ownership follows find().
    pub fn symtableFind(self: *Array, key: []const u8) ?*c.zval {
        if (key.len == 0 or (key.len == 1 and key[0] == '-')) return self.find(key);
        return c.zend_symtable_str_find(self.ptr(), key.ptr, key.len);
    }

    /// Add or update like PHP's `$array[$key] = $value`. Ownership follows update().
    /// Requires mutable, uniquely owned storage.
    pub fn symtableUpdate(self: *Array, key: []const u8, value: *c.zval) *c.zval {
        if (key.len == 0 or (key.len == 1 and key[0] == '-')) return self.update(key, value);
        return c.zend_symtable_str_update(self.ptr(), key.ptr, key.len, value).?;
    }

    /// Delete like PHP's `unset($array[$key])`, destroying the stored value.
    pub fn symtableDelete(self: *Array, key: []const u8) Error!void {
        if (key.len == 0 or (key.len == 1 and key[0] == '-')) return self.delete(key);
        if (c.zend_symtable_str_del(self.ptr(), key.ptr, key.len) != c.SUCCESS) return Error.NotFound;
    }

    /// Like find(), with a borrowed Zend string key; no numeric-string conversion.
    pub fn findStr(self: *Array, key: *String) ?*c.zval {
        return c.zend_hash_find(self.ptr(), key.ptr());
    }

    /// Like find(), unwrapping PHP references but not IS_INDIRECT.
    /// The result is borrowed; keep its owner and entry valid while using it.
    pub fn findDeref(self: *Array, key: []const u8) ?*c.zval {
        return c.zend_hash_str_find_deref(self.ptr(), key.ptr, key.len);
    }

    /// Like findDeref(), with a borrowed Zend string key.
    pub fn findStrDeref(self: *Array, key: *String) ?*c.zval {
        return c.zend_hash_find_deref(self.ptr(), key.ptr());
    }

    /// Find an IS_PTR pointing to T, without retaining it.
    /// Pointee ownership follows updatePtr().
    pub fn findPtr(self: *Array, comptime T: type, key: []const u8) ?*T {
        const value = c.zend_hash_str_find_ptr(self.ptr(), key.ptr, key.len);
        return if (value != null) @ptrCast(@alignCast(value)) else null;
    }

    /// Like findPtr(), with a borrowed Zend string key.
    pub fn findStrPtr(self: *Array, comptime T: type, key: *String) ?*T {
        const value = c.zend_hash_find_ptr(self.ptr(), key.ptr());
        return if (value != null) @ptrCast(@alignCast(value)) else null;
    }

    /// Find a value by index.
    ///
    /// Ownership: borrowed zval pointer owned by the array; addref/copy before
    /// storing it beyond the array or mutating the table.
    pub fn findIndex(self: *Array, index: isize) ?*c.zval {
        return c.zend_hash_index_find(self.ptr(), @bitCast(index));
    }

    /// Like findDeref(), keyed by index.
    pub fn findIndexDeref(self: *Array, index: isize) ?*c.zval {
        return c.zend_hash_index_find_deref(self.ptr(), @bitCast(index));
    }

    /// Like findPtr(), keyed by index.
    pub fn findIndexPtr(self: *Array, comptime T: type, index: isize) ?*T {
        const value = c.zend_hash_index_find_ptr(self.ptr(), @bitCast(index));
        return if (value != null) @ptrCast(@alignCast(value)) else null;
    }

    /// Check if a raw string key exists; see find() for numeric strings.
    pub fn has(self: *Array, key: []const u8) bool {
        return self.find(key) != null;
    }

    /// Check whether a Zend string key exists, including null values.
    pub fn hasStr(self: *Array, key: *String) bool {
        return self.findStr(key) != null;
    }

    /// Check if an index exists
    pub fn hasIndex(self: *Array, index: isize) bool {
        return self.findIndex(index) != null;
    }

    /// Delete a value by raw string key; see find() for numeric strings.
    pub fn delete(self: *Array, key: []const u8) Error!void {
        if (c.zend_hash_str_del(self.ptr(), key.ptr, key.len) != c.SUCCESS) {
            return Error.NotFound;
        }
    }

    /// Delete by a borrowed Zend string key, destroying the stored value.
    /// Requires mutable, uniquely owned storage.
    pub fn deleteStr(self: *Array, key: *String) Error!void {
        if (c.zend_hash_del(self.ptr(), key.ptr()) != c.SUCCESS) {
            return Error.NotFound;
        }
    }

    /// Delete a value by index
    pub fn deleteIndex(self: *Array, index: isize) Error!void {
        if (c.zend_hash_index_del(self.ptr(), @bitCast(index)) != c.SUCCESS) {
            return Error.NotFound;
        }
    }

    /// Find a slot or insert PHP null; retains the key without numeric conversion.
    /// Requires mutable, uniquely owned storage. The slot is borrowed; release its
    /// contents before overwriting it, and do not keep it across table mutations.
    pub fn lookupStr(self: *Array, key: *String) *c.zval {
        return c.zend_hash_lookup(self.ptr(), key.ptr()).?;
    }

    /// Like lookupStr(), keyed by index.
    pub fn lookupIndex(self: *Array, index: isize) *c.zval {
        return c.zend_hash_index_lookup(self.ptr(), @bitCast(index)).?;
    }

    /// Rebuild the hash index and compact holes, preserving keys.
    /// Requires a mutable, uniquely owned mixed table; may invalidate entry pointers/iterators.
    pub fn rehash(self: *Array) void {
        c.zend_hash_rehash(self.ptr());
    }

    /// Copy source entries into this array, overwriting matching keys and
    /// retaining other existing entries. Numeric keys are preserved.
    ///
    /// Ownership: source is borrowed; the target owns the copied values using
    /// Zend's zval_add_ref copy constructor. Values are shallow-copied, with
    /// single-owner reference wrappers unwrapped according to Zend semantics.
    /// The target must be mutable, uniquely owned, and distinct from source;
    /// this raw array wrapper does not perform copy-on-write separation.
    pub fn copy(self: *Array, source: *Array) void {
        c.zend_hash_copy(self.ptr(), source.ptr(), c.zval_add_ref);
    }

    /// Merge source entries, preserving numeric keys. Matching keys are
    /// replaced when overwrite is true and skipped otherwise.
    ///
    /// Ownership and target preconditions follow copy(). Only inserted or
    /// replaced values gain ownership; skipped source entries are unchanged.
    /// This is Zend hash merging, not PHP array_merge() numeric renumbering.
    pub fn merge(self: *Array, source: *Array, overwrite: bool) void {
        c.zend_hash_merge(self.ptr(), source.ptr(), c.zval_add_ref, overwrite);
    }

    /// Compare arrays using a typed value callback. Zend compares sizes and
    /// keys; ordered additionally requires matching iteration order. The
    /// callback determines value equality, not the ordered flag.
    ///
    /// Ownership: arrays are borrowed; callback arguments are borrowed read-only
    /// zval slots (referenced payloads are not deeply immutable). Keep both arrays
    /// alive and do not invalidate their entries during comparison. Reference
    /// wrappers are passed through; dereferencing is the callback's policy.
    /// Returns the raw Zend comparison result, not necessarily -1, 0, or 1.
    /// Pending PHP exceptions return PhpException or UnwindExit; Zend bailouts propagate.
    pub fn compare(self: *Array, other: *Array, compare_fn: fn (*const c.zval, *const c.zval) c_int, ordered: bool) exception.Error!c_int {
        const Cb = struct {
            fn cb(a: ?*const anyopaque, b: ?*const anyopaque) callconv(.c) c_int {
                const left: *const c.zval = @ptrCast(@alignCast(a.?));
                const right: *const c.zval = @ptrCast(@alignCast(b.?));
                return compare_fn(left, right);
            }
        };
        const result = c.zend_hash_compare(self.ptr(), other.ptr(), Cb.cb, ordered);
        try exception.check();
        return result;
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
    /// The callback must return `.stop` to stop after a PHP exception. Pending
    /// exceptions are reported as PhpException or UnwindExit after traversal returns.
    pub fn apply(self: *Array, apply_fn: fn (*c.zval) ApplyResult) exception.Error!void {
        const Cb = struct {
            fn cb(zv: ?*c.zval) callconv(.c) c_int {
                return @backingInt(apply_fn(zv.?));
            }
        };
        c.zend_hash_apply(self.ptr(), Cb.cb);
        try exception.check();
    }

    /// Like apply(), in reverse order; values are borrowed and removals are not rolled back.
    /// Removal requires mutable, uniquely owned storage. Do not otherwise invalidate entries.
    pub fn reverseApply(self: *Array, apply_fn: fn (*c.zval) ApplyResult) exception.Error!void {
        const Cb = struct {
            fn cb(zv: ?*c.zval) callconv(.c) c_int {
                return @backingInt(apply_fn(zv.?));
            }
        };
        c.zend_hash_reverse_apply(self.ptr(), Cb.cb);
        try exception.check();
    }

    /// Apply a callback to each element, passing a user-provided argument pointer.
    /// Callback control flow and exception handling follow apply().
    pub fn applyWithArg(
        self: *Array,
        comptime ArgType: type,
        apply_fn: fn (*c.zval, *ArgType) ApplyResult,
        arg: *ArgType,
    ) exception.Error!void {
        const Cb = struct {
            fn cb(zv: ?*c.zval, a: ?*anyopaque) callconv(.c) c_int {
                return @backingInt(apply_fn(zv.?, @ptrCast(@alignCast(a.?))));
            }
        };
        c.zend_hash_apply_with_argument(self.ptr(), Cb.cb, arg);
        try exception.check();
    }

    pub const SortOrder = enum(c_int) { less = -1, equal = 0, greater = 1 };

    /// Sort the array in-place with a custom compare function and optional renumbering.
    /// Callback results are passed through; returning `.equal` does not stop
    /// sorting. Zend may invoke further callbacks with a pending PHP exception.
    /// Pending exceptions are reported as PhpException or UnwindExit after sorting returns;
    /// changes are not rolled back.
    pub fn sort(self: *Array, compare_fn: fn (*c.Bucket, *c.Bucket) SortOrder, renumber: bool) exception.Error!void {
        const Cb = struct {
            fn cb(a: ?*c.Bucket, b: ?*c.Bucket) callconv(.c) c_int {
                return @backingInt(compare_fn(a.?, b.?));
            }
        };
        c.zend_hash_sort(self.ptr(), Cb.cb, renumber);
        try exception.check();
    }

    /// Get refcount
    pub inline fn refcount(self: *Array) u32 {
        return c.zend_gc_refcount(&self.ptr().gc);
    }

    /// Increment refcount; a no-op for immutable arrays.
    ///
    /// Ownership: caller owns the added reference and must release/delref it.
    pub fn addref(self: *Array) void {
        c.zend_gc_try_addref(&self.ptr().gc);
    }

    /// Decrement refcount without freeing; a no-op for immutable arrays.
    pub fn delref(self: *Array) void {
        c.zend_gc_try_delref(&self.ptr().gc);
    }

    /// Check if array is immutable
    pub inline fn isImmutable(self: *Array) bool {
        return (c.GC_FLAGS(self.ptr()) & c.GC_IMMUTABLE) != 0;
    }

    pub const Key = union(enum) {
        int: isize,
        string: [:0]const u8,
    };

    pub const Entry = struct {
        /// Ownership: borrowed key view owned by the array bucket.
        key: Key,
        /// Ownership: borrowed zval pointer owned by the array bucket.
        value: *c.zval,
    };

    inline fn isPacked(ht: *c.HashTable) bool {
        return (ht.u.flags & c.HASH_FLAG_PACKED) != 0;
    }

    inline fn packedValues(ht: *c.HashTable) [*]c.zval {
        return @ptrCast(c.phpz_hash_table_get_ar_packed(ht));
    }

    inline fn buckets(ht: *c.HashTable) [*]c.Bucket {
        return @ptrCast(@alignCast(c.phpz_hash_table_get_ar_packed(ht)));
    }

    inline fn valueAt(ht: *c.HashTable, pos: u32) *c.zval {
        return if (isPacked(ht)) &packedValues(ht)[pos] else &buckets(ht)[pos].val;
    }

    inline fn keyAt(ht: *c.HashTable, pos: u32) Key {
        if (isPacked(ht)) return .{ .int = @intCast(pos) };
        const bucket = &buckets(ht)[pos];
        return if (bucket.key) |k| .{ .string = String.from(k).slice() } else .{ .int = @bitCast(bucket.h) };
    }

    /// First used slot at or after `pos`, or nNumUsed. Mirrors _zend_hash_get_valid_pos().
    inline fn validPos(ht: *c.HashTable, start: u32) u32 {
        var pos = start;
        while (pos < ht.nNumUsed and Zval.raw.is(valueAt(ht, pos), .undef)) pos += 1;
        return pos;
    }

    /// Next position after the current valid one, like zend_hash_move_forward_ex().
    inline fn moveForward(ht: *c.HashTable, pos: u32) u32 {
        const current_pos = validPos(ht, pos);
        return if (current_pos < ht.nNumUsed) validPos(ht, current_pos + 1) else pos;
    }

    /// Builds a list (keys 0..n-1) without hashing, like ZEND_HASH_FILL_PACKED.
    /// Appended values must not be IS_UNDEF, including after dereferencing
    /// .mixed inputs. Use null for an empty value.
    /// The builder owns the array: append, then finish() before any other use.
    /// A Zend bailout while building leaks the unfinished entries until request shutdown.
    pub const ListBuilder = struct {
        ht: *c.HashTable,
        cursor: [*]c.zval,
        end: [*]c.zval,

        /// Reserve `capacity` slots; the array still grows past it when needed.
        pub fn init(capacity: u32) ListBuilder {
            const ht: *c.HashTable = c.zend_new_array(capacity);
            c.zend_hash_real_init_packed(ht);
            return at(ht, 0);
        }

        fn at(ht: *c.HashTable, used: u32) ListBuilder {
            const values = packedValues(ht);
            return .{ .ht = ht, .cursor = values + used, .end = values + ht.nTableSize };
        }

        /// Append the next element; ownership follows `Zval.raw.set`.
        pub inline fn append(self: *ListBuilder, comptime zk: Zval.Kind, value: Zval.Type(zk)) void {
            if (zk == .undef) @compileError("expected a defined value, found IS_UNDEF");
            if (self.cursor == self.end) self.* = grow(self.*);
            Zval.raw.set(&self.cursor[0], zk, value);
            self.cursor += 1;
        }

        /// Like append(), for builders created with enough capacity for every element.
        pub inline fn appendAssumeCapacity(self: *ListBuilder, comptime zk: Zval.Kind, value: Zval.Type(zk)) void {
            if (zk == .undef) @compileError("expected a defined value, found IS_UNDEF");
            std.debug.assert(self.cursor != self.end);
            Zval.raw.set(&self.cursor[0], zk, value);
            self.cursor += 1;
        }

        /// Append a non-IS_UNDEF zval, transferring its contents without addref.
        pub inline fn appendValue(self: *ListBuilder, value: *const c.zval) void {
            if (self.cursor == self.end) self.* = grow(self.*);
            Zval.raw.copyValue(&self.cursor[0], value);
            self.cursor += 1;
        }

        // By value, so the builder's address never escapes and it stays in registers.
        noinline fn grow(builder: ListBuilder) ListBuilder {
            @branchHint(.cold);
            const used = builder.publish();
            c.zend_hash_packed_grow(builder.ht);
            return at(builder.ht, used);
        }

        fn publish(self: ListBuilder) u32 {
            const ht = self.ht;
            const used: u32 = @intCast(self.cursor - packedValues(ht));
            ht.nNumOfElements += used - ht.nNumUsed;
            ht.nNumUsed = used;
            ht.nNextFreeElement = used;
            ht.nInternalPointer = 0;
            return used;
        }

        /// Ownership: the caller owns the returned array; the builder must not be reused.
        pub fn finish(self: *ListBuilder) *Array {
            _ = self.publish();
            return .from(self.ht);
        }
    };

    // The iterator supplies the first callback argument (value or entry).
    fn EachArgs(comptime Callback: type, comptime First: type) type {
        const Args = std.meta.ArgsTuple(Callback);
        const types = @typeInfo(Args).@"struct".field_types;
        if (types.len == 0 or types[0] != First)
            @compileError("array callback first parameter must be " ++ @typeName(First));
        return @Tuple(types[1..]);
    }

    /// Iterate values with a comptime callback — IS_UNDEF and user code in same scope.
    ///
    /// Ownership: callback values are borrowed from the array.
    ///
    /// Additional callback parameters are supplied by the typed `args` tuple.
    /// Pass `.{}` without extra parameters.
    ///
    /// Equivalent to C's `ZEND_HASH_FOREACH_VAL`.
    /// Unlike pull-based iterators, this inlines the loop body so the compiler can
    /// eliminate redundant type checks (e.g., IS_UNDEF + IS_LONG in the same scope).
    ///
    /// Example:
    /// ```zig
    /// var sum: i64 = 0;
    /// arr.eachValue(struct {
    ///     fn callback(zv: *c.zval, s: *i64) void {
    ///         if (Zval.raw.is(zv, .int)) s.* += Zval.raw.asUnchecked(zv, .int);
    ///     }
    /// }.callback, .{&sum});
    /// ```
    pub inline fn eachValue(
        self: *Array,
        comptime callback: anytype,
        args: EachArgs(@TypeOf(callback), *c.zval),
    ) void {
        // Separate loops give each layout a constant element stride.
        const ht = self.ptr();
        if (isPacked(ht)) {
            var cursor = packedValues(ht);
            const end = cursor + ht.nNumUsed;
            while (cursor != end) : (cursor += 1) {
                const zv = &cursor[0];
                if (Zval.raw.is(zv, .undef)) {
                    @branchHint(.unlikely);
                    continue;
                }
                @call(.always_inline, callback, .{zv} ++ args);
            }
        } else {
            var cursor = buckets(ht);
            const end = cursor + ht.nNumUsed;
            while (cursor != end) : (cursor += 1) {
                const zv = &cursor[0].val;
                if (Zval.raw.is(zv, .undef)) {
                    @branchHint(.unlikely);
                    continue;
                }
                @call(.always_inline, callback, .{zv} ++ args);
            }
        }
    }

    /// Iterate key-value pairs with a comptime callback — IS_UNDEF and user code in same scope.
    ///
    /// Ownership: callback entries contain borrowed keys and values from the array.
    ///
    /// Equivalent to C's `ZEND_HASH_FOREACH`. Walks the bucket array directly.
    /// The callback receives an `Entry` (`.key` and `.value`).
    /// Additional callback parameters are supplied by the typed `args` tuple.
    /// Pass `.{}` without extra parameters.
    ///
    /// Example:
    /// ```zig
    /// arr.each(struct {
    ///     fn callback(e: Array.Entry, ctx: *Ctx) void {
    ///         switch (e.key) {
    ///             .int => |i| // numeric key
    ///             .string => |s| // string key
    ///         }
    ///     }
    /// }.callback, .{&ctx});
    /// ```
    pub inline fn each(
        self: *Array,
        comptime callback: anytype,
        args: EachArgs(@TypeOf(callback), Entry),
    ) void {
        const ht = self.ptr();
        if (isPacked(ht)) {
            for (packedValues(ht)[0..ht.nNumUsed], 0..) |*zv, index| {
                if (Zval.raw.is(zv, .undef)) {
                    @branchHint(.unlikely);
                    continue;
                }
                @call(.always_inline, callback, .{Entry{ .key = .{ .int = @intCast(index) }, .value = zv }} ++ args);
            }
        } else {
            for (buckets(ht)[0..ht.nNumUsed]) |*bucket| {
                if (Zval.raw.is(&bucket.val, .undef)) {
                    @branchHint(.unlikely);
                    continue;
                }
                const key: Key = if (bucket.key) |k|
                    .{ .string = String.from(k).slice() }
                else
                    .{ .int = @bitCast(bucket.h) };
                @call(.always_inline, callback, .{Entry{ .key = key, .value = &bucket.val }} ++ args);
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
            self.pos = validPos(self.ht, 0);
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
            self.pos = moveForward(self.ht, self.pos);
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
            return keyAt(self.ht, validPos(self.ht, self.pos));
        }

        /// Unsafe: peek the current value without bounds check. Prefer `currentValue()`.
        ///
        /// Ownership: borrowed zval pointer owned by the array.
        pub fn peekValue(self: *Iterator) *c.zval {
            return valueAt(self.ht, validPos(self.ht, self.pos));
        }

        inline fn hasMore(self: *Iterator) bool {
            return validPos(self.ht, self.pos) < self.ht.nNumUsed;
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
            self.pos = validPos(self.ht, 0);
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
            self.pos = moveForward(self.ht, self.pos);
        }

        /// Unsafe: peek without bounds check. Prefer `current()`.
        ///
        /// Ownership: borrowed key view owned by the array.
        pub fn peek(self: *KeyIterator) Key {
            return keyAt(self.ht, validPos(self.ht, self.pos));
        }

        inline fn hasMore(self: *KeyIterator) bool {
            return validPos(self.ht, self.pos) < self.ht.nNumUsed;
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
            self.pos = validPos(self.ht, 0);
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
            self.pos = moveForward(self.ht, self.pos);
        }

        /// Unsafe: peek without bounds check. Prefer `current()`.
        ///
        /// Ownership: borrowed zval pointer owned by the array.
        pub fn peek(self: *ValueIterator) *c.zval {
            return valueAt(self.ht, validPos(self.ht, self.pos));
        }

        inline fn hasMore(self: *ValueIterator) bool {
            return validPos(self.ht, self.pos) < self.ht.nNumUsed;
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
                        .{ .string = String.from(k).slice() }
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
                        .{ .string = String.from(k).slice() }
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
                self.pos = validPos(self.ht, 0);
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
                self.pos = moveForward(self.ht, self.pos);
            }

            /// Unsafe: peek without bounds check. Prefer `current()`.
            ///
            /// Ownership: borrowed pointer owned by the array.
            pub fn peek(self: *Self) *T {
                const info = valueAt(self.ht, validPos(self.ht, self.pos)).value.ptr.?;
                return @ptrCast(@alignCast(info));
            }

            inline fn hasMore(self: *Self) bool {
                return validPos(self.ht, self.pos) < self.ht.nNumUsed;
            }
        };
    }

    /// Create a HashPosition iterator (key + value). It re-validates its position
    /// against the table on every step, like zend_hash_*_ex(), so it tolerates
    /// deletions and reallocation between steps. Prefer `fastIterator` for read-only loops.
    pub fn iterator(self: *Array) Iterator {
        return Iterator.init(self);
    }

    /// Create a HashPosition key-only iterator; see iterator().
    pub fn keyIterator(self: *Array) KeyIterator {
        return KeyIterator.init(self);
    }

    /// Create a HashPosition value-only iterator; see iterator().
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
