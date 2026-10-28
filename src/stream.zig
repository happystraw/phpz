const std = @import("std");
const c = @import("c.zig").c;
const exception = @import("exception.zig");
const Resource = @import("zend/resource.zig").Resource;
const String = @import("zend/string.zig").String;
const Zval = @import("zval.zig").Zval;

/// PHP stream operations.
pub const Stream = opaque {
    /// Return PHP's runtime resource type ID for ordinary streams.
    pub const resourceTypeId = c.php_file_le_stream;
    /// Return PHP's runtime resource type ID for persistent streams.
    pub const persistentResourceTypeId = c.php_file_le_pstream;
    /// Return PHP's runtime resource type ID for stream filters.
    pub const filterResourceTypeId = c.php_file_le_stream_filter;

    pub const OpenOptions = struct {
        /// Search PHP's include_path.
        use_path: bool = false,
        /// Bypass URL wrapper lookup, treating the path as a local filename.
        ignore_url: bool = false,
        /// Allow PHP to report stream-opening errors.
        report_errors: bool = false,
        /// Request a seekable stream for reading. PHP may close the original and
        /// return a temporary copy; writes to that copy do not reach the original.
        must_seek: bool = false,
        /// Open or reuse a persistent stream; the wrapper must support persistence.
        persistent: bool = false,
    };

    /// Caller-owned storage for a directory entry name, including its NUL terminator.
    pub const DirBuffer = [c.MAXPATHLEN]u8;

    /// No flags are enabled by default; use a preset for PHP's standard close modes.
    pub const FreeOptions = packed struct(i32) {
        /// Call the stream's close operation.
        call_dtor: bool = false,
        /// Release the stream's storage.
        release_stream: bool = false,
        /// Preserve the underlying handle when calling the close operation.
        preserve_handle: bool = false,
        /// The call originates from the resource destructor.
        rsrc_dtor: bool = false,
        /// Remove the persistent stream's registry entry.
        persistent: bool = false,
        /// Do not redirect destruction to the enclosing stream.
        ignore_enclosing: bool = false,
        /// Keep the associated resource without decrementing its reference count.
        keep_rsrc: bool = false,

        _: u25 = 0,

        /// PHP_STREAM_FREE_CLOSE: close and release the stream.
        pub const close: FreeOptions = @bitCast(@as(i32, c.PHP_STREAM_FREE_CLOSE));
        /// PHP_STREAM_FREE_CLOSE_CASTED: close and release, preserving the underlying handle.
        pub const close_casted: FreeOptions = @bitCast(@as(i32, c.PHP_STREAM_FREE_CLOSE_CASTED));
        /// PHP_STREAM_FREE_CLOSE_PERSISTENT: close and release, removing the persistent registry entry.
        pub const close_persistent: FreeOptions = @bitCast(@as(i32, c.PHP_STREAM_FREE_CLOSE_PERSISTENT));
    };

    pub const SeekWhence = enum(i32) {
        start = c.SEEK_SET,
        current = c.SEEK_CUR,
        end = c.SEEK_END,
        _,
    };

    pub const LockMode = enum(c_int) {
        shared = c.LOCK_SH,
        exclusive = c.LOCK_EX,
    };

    /// Native PHP stat fields; layout and available fields depend on the target.
    pub const Stat = c.zend_stat_t;

    pub const OptionError = error{ UnsupportedOperation, SetOptionFailed };
    pub const LockError = error{ UnsupportedOperation, LockFailed, WouldBlock };

    /// Wrap an existing pointer without changing ownership.
    pub inline fn from(stream: *c.php_stream) *Stream {
        return @ptrCast(stream);
    }

    /// Borrow the underlying C pointer.
    pub inline fn ptr(self: *Stream) *c.php_stream {
        return @ptrCast(@alignCast(self));
    }

    /// Borrow a stream; keep its resource alive and open. Invalid resources raise PHP TypeError.
    pub fn fromResource(resource: *Resource) exception.Error!*Stream {
        const raw = c.zend_fetch_resource2(resource.ptr(), "stream", resourceTypeId(), persistentResourceTypeId()) orelse
            return exception.pending() orelse error.PhpException;
        return @ptrCast(@alignCast(raw));
    }

    /// Return whether the stream is persistent.
    pub fn isPersistent(self: *Stream) bool {
        return c.phpz_stream_is_persistent(self.ptr());
    }

    /// Owns one request resource reference; use toZval() or closePersistent().
    /// Null means absent; an ID belonging to another resource type is an error.
    pub fn fromPersistentId(id: [:0]const u8) error{PersistentResourceTypeMismatch}!?*Stream {
        var stream: ?*c.php_stream = null;
        return switch (c.php_stream_from_persistent_id(id.ptr, @ptrCast(&stream))) {
            c.PHP_STREAM_PERSISTENT_SUCCESS => .from(stream.?),
            c.PHP_STREAM_PERSISTENT_NOT_EXIST => null,
            else => error.PersistentResourceTypeMismatch,
        };
    }

    /// Transfer an owned resource reference to an undefined/null zval without addref.
    /// PHP then owns the stream; do not close it or transfer it again.
    pub fn toZval(self: *Stream, destination: *Zval) void {
        c.phpz_stream_to_zval(self.ptr(), destination.ptr());
    }

    /// Open without a context; owns a request resource reference, even when reusing a stream.
    /// Transfer it to PHP or use close/closePersistent according to isPersistent().
    pub fn open(path: [:0]const u8, mode: [:0]const u8, options: OpenOptions) error{OpenFailed}!*Stream {
        const flags: i32 = (if (options.use_path) @as(i32, c.USE_PATH) else 0) |
            (if (options.ignore_url) @as(i32, c.IGNORE_URL) else 0) |
            (if (options.report_errors) @as(i32, c.REPORT_ERRORS) else 0) |
            (if (options.must_seek) @as(i32, c.STREAM_MUST_SEEK) else 0) |
            (if (options.persistent) @as(i32, c.STREAM_OPEN_PERSISTENT) else 0);
        const stream = c.phpz_stream_open(path.ptr, mode.ptr, flags) orelse return error.OpenFailed;
        return .from(stream);
    }

    /// Open an owned directory stream without a context; use close() when done.
    pub fn openDir(path: [:0]const u8, options: struct { ignore_url: bool = false, report_errors: bool = false }) error{OpenFailed}!*Stream {
        const flags: i32 = (if (options.ignore_url) @as(i32, c.IGNORE_URL) else 0) |
            (if (options.report_errors) @as(i32, c.REPORT_ERRORS) else 0);
        return .from(c.phpz_stream_opendir(path.ptr, flags) orelse return error.OpenFailed);
    }

    /// Read a directory name into buffer without filtering dot entries; null means end or error.
    /// The returned name borrows buffer. Requires a directory stream; rewind() restarts it.
    pub fn readDir(self: *Stream, buffer: *DirBuffer) ?[:0]u8 {
        var entry: c.php_stream_dirent = undefined;
        if (c.php_stream_readdir(self.ptr(), &entry) == null) return null;
        const name = std.mem.sliceTo(&entry.d_name, 0);
        @memcpy(buffer[0..name.len], name);
        buffer[name.len] = 0;
        return buffer[0..name.len :0];
    }

    /// Consume an owned nonpersistent stream; preserve PHP's result, including process exit status.
    /// Do not close borrowed resources or retry after a nonzero result.
    pub fn close(self: *Stream) i32 {
        return c.php_stream_close(self.ptr());
    }

    /// Consume an owned persistent reference and remove the stream from the persistent registry.
    /// Also invalidates aliases; do not close borrowed resources or retry after a nonzero result.
    pub fn closePersistent(self: *Stream) i32 {
        return c.php_stream_pclose(self.ptr());
    }

    /// Release according to explicit ownership flags; preserve PHP's result.
    /// Does not check NO_FCLOSE. A released pointer is invalid even after a nonzero result.
    pub fn free(self: *Stream, options: FreeOptions) i32 {
        return c.php_stream_free(self.ptr(), @backingInt(options));
    }

    /// Read into borrowed storage; zero can mean EOF or temporarily unavailable data.
    pub fn read(self: *Stream, buffer: []u8) error{ReadFailed}!usize {
        const count = c.php_stream_read(self.ptr(), buffer.ptr, buffer.len);
        if (count < 0) return error.ReadFailed;
        return @intCast(count);
    }

    /// Read up to len bytes into an owned string; release it or transfer it to PHP. EOF returns empty.
    pub fn readToStr(self: *Stream, len: usize) error{ReadFailed}!*String {
        return .from(c.php_stream_read_to_str(self.ptr(), len) orelse return error.ReadFailed);
    }

    /// Return a slice borrowing buffer, retaining newlines and reserving one byte for NUL.
    /// Null means no data, a read error, or a buffer shorter than two bytes.
    pub fn getLine(self: *Stream, buffer: []u8) ?[]u8 {
        if (buffer.len < 2) return null;
        var len: usize = 0;
        if (c.php_stream_get_line(self.ptr(), buffer.ptr, buffer.len, &len) == null) return null;
        return buffer[0..len];
    }

    /// Borrow both streams; null limit copies until EOF or temporarily unavailable data.
    /// copied preserves PHP's count, which is not a reliable resume offset on failure.
    pub fn copyTo(self: *Stream, destination: *Stream, limit: ?usize, copied: *usize) error{CopyFailed}!void {
        if (c.phpz_stream_copy_to_stream(self.ptr(), destination.ptr(), limit orelse c.PHP_STREAM_COPY_ALL, copied) != c.SUCCESS)
            return error.CopyFailed;
    }

    /// Write borrowed bytes, preserving partial writes and zero progress.
    pub fn write(self: *Stream, bytes: []const u8) error{WriteFailed}!usize {
        const count = c.php_stream_write(self.ptr(), bytes.ptr, bytes.len);
        if (count < 0) return error.WriteFailed;
        return @intCast(count);
    }

    /// Seek relative to the selected origin.
    pub fn seek(self: *Stream, offset: c.zend_off_t, whence: SeekWhence) error{SeekFailed}!void {
        if (c.php_stream_seek(self.ptr(), offset, @backingInt(whence)) != 0) return error.SeekFailed;
    }

    /// Seek to the start of the stream.
    pub inline fn rewind(self: *Stream) error{SeekFailed}!void {
        return self.seek(0, .start);
    }

    /// Return PHP's tracked position.
    pub fn tell(self: *Stream) c.zend_off_t {
        return c.php_stream_tell(self.ptr());
    }

    /// Check for EOF; PHP may probe the underlying stream.
    pub fn eof(self: *Stream) bool {
        return c.php_stream_eof(self.ptr());
    }

    /// Query wrapper support; a subsequent operation may still fail.
    pub fn supportsSync(self: *Stream) bool {
        return c.php_stream_sync_supported(self.ptr()) != 0;
    }

    /// Query wrapper support; a subsequent operation may still fail.
    pub fn supportsTruncate(self: *Stream) bool {
        return c.php_stream_truncate_supported(self.ptr()) != 0;
    }

    /// Query wrapper support; a subsequent operation may still fail.
    pub fn supportsLock(self: *Stream) bool {
        return c.php_stream_supports_lock(self.ptr()) != 0;
    }

    /// Acquire or change a lock. Nonblocking contention reports WouldBlock when
    /// the wrapper supplies EWOULDBLOCK; custom wrappers may only report LockFailed.
    pub fn lock(self: *Stream, mode: LockMode, non_blocking: bool) LockError!void {
        const flags = @backingInt(mode) | (if (non_blocking) @as(c_int, c.LOCK_NB) else 0);
        try self.changeLock(flags);
    }

    /// Release a lock without closing the stream.
    pub fn unlock(self: *Stream) LockError!void {
        try self.changeLock(c.LOCK_UN);
    }

    fn changeLock(self: *Stream, flags: c_int) LockError!void {
        const errno_ptr = std.c._errno();
        errno_ptr.* = 0;
        const result = c.php_stream_lock(self.ptr(), flags);
        const would_block = result != 0 and errno_ptr.* == c.EWOULDBLOCK;
        if (result == c.PHP_STREAM_OPTION_RETURN_NOTIMPL) return error.UnsupportedOperation;
        if (result != 0) return if (would_block) error.WouldBlock else error.LockFailed;
    }

    /// Change blocking mode. Successful wrappers may return the previous mode.
    pub fn setBlocking(self: *Stream, blocking: bool) OptionError!void {
        const result = c.php_stream_set_option(self.ptr(), c.PHP_STREAM_OPTION_BLOCKING, @intFromBool(blocking), null);
        if (result == c.PHP_STREAM_OPTION_RETURN_NOTIMPL) return error.UnsupportedOperation;
        if (result < 0) return error.SetOptionFailed;
    }

    /// Set a read timeout; microseconds must be below 1,000,000 and seconds must
    /// fit the target's timeval. Support and timeout behavior depend on the wrapper.
    pub fn setReadTimeout(self: *Stream, seconds: u64, microseconds: u32) (OptionError || error{InvalidTimeout})!void {
        var timeout: c.struct_timeval = std.mem.zeroes(c.struct_timeval);
        if (microseconds >= 1_000_000) return error.InvalidTimeout;
        timeout.tv_sec = std.math.cast(@TypeOf(timeout.tv_sec), seconds) orelse return error.InvalidTimeout;
        timeout.tv_usec = @intCast(microseconds);
        try checkOption(c.php_stream_set_option(self.ptr(), c.PHP_STREAM_OPTION_READ_TIMEOUT, 0, &timeout));
    }

    /// Zero disables buffering; nonzero requests full buffering with this size.
    /// PHP's read-buffer fallback only toggles buffering and ignores the size.
    pub fn setReadBuffer(self: *Stream, size: usize) OptionError!void {
        var buffer_size = size;
        try checkOption(c.php_stream_set_option(self.ptr(), c.PHP_STREAM_OPTION_READ_BUFFER, if (size == 0) c.PHP_STREAM_BUFFER_NONE else c.PHP_STREAM_BUFFER_FULL, &buffer_size));
    }

    /// Zero disables buffering; nonzero requests full buffering with this size.
    /// The wrapper may reject the request. Flush pending writes before changing buffering.
    pub fn setWriteBuffer(self: *Stream, size: usize) OptionError!void {
        var buffer_size = size;
        try checkOption(c.php_stream_set_option(self.ptr(), c.PHP_STREAM_OPTION_WRITE_BUFFER, if (size == 0) c.PHP_STREAM_BUFFER_NONE else c.PHP_STREAM_BUFFER_FULL, &buffer_size));
    }

    /// Set the internal chunk size (1..INT_MAX), returning the previous size.
    /// PHP caps a previous size larger than INT_MAX at INT_MAX.
    pub fn setChunkSize(self: *Stream, size: usize) (OptionError || error{InvalidChunkSize})!usize {
        if (size == 0 or size > std.math.maxInt(c_int)) return error.InvalidChunkSize;
        const result = c.php_stream_set_chunk_size(self.ptr(), @as(c_int, @intCast(size)));
        if (result == c.PHP_STREAM_OPTION_RETURN_NOTIMPL) return error.UnsupportedOperation;
        if (result <= 0) return error.SetOptionFailed;
        return @intCast(result);
    }

    fn checkOption(result: c_int) OptionError!void {
        if (result == c.PHP_STREAM_OPTION_RETURN_NOTIMPL) return error.UnsupportedOperation;
        if (result != c.PHP_STREAM_OPTION_RETURN_OK) return error.SetOptionFailed;
    }

    /// Return stat information for the open stream without changing its position.
    pub fn stat(self: *Stream) error{StatFailed}!Stat {
        var info: c.php_stream_statbuf = std.mem.zeroes(c.php_stream_statbuf);
        if (c.php_stream_stat(self.ptr(), &info) != 0) return error.StatFailed;
        return info.sb;
    }

    /// Flush stream buffers; this does not guarantee durable storage.
    pub fn flush(self: *Stream) error{FlushFailed}!void {
        if (c.php_stream_flush(self.ptr()) != 0) return error.FlushFailed;
    }

    /// Change the stream size; position behavior follows the wrapper.
    pub fn truncate(self: *Stream, size: usize) error{TruncateFailed}!void {
        if (c.php_stream_truncate_set_size(self.ptr(), size) != 0) return error.TruncateFailed;
    }

    /// Request filesystem synchronization. Flush stream buffers separately first.
    pub fn sync(self: *Stream, data_only: bool) error{SyncFailed}!void {
        if (c.php_stream_sync(self.ptr(), data_only) != 0) return error.SyncFailed;
    }
};

test {
    std.testing.refAllDecls(Stream);
}
