const std = @import("std");

const c = @import("../c.zig").c;
const heap = @import("../heap.zig");

/// Script file handle. Initialize during an active request and deinitialize
/// owned handles before request shutdown.
pub const FileHandle = opaque {
    pub inline fn from(fh: *c.zend_file_handle) *FileHandle {
        return @ptrCast(fh);
    }

    pub inline fn ptr(self: *FileHandle) *c.zend_file_handle {
        return @ptrCast(@alignCast(self));
    }

    /// Allocate a handle with PHP's allocator and copy the filename.
    /// The file is opened lazily. Release with deinit before request shutdown.
    pub fn init(filename: [:0]const u8) *FileHandle {
        const fh: *c.zend_file_handle = @ptrCast(@alignCast(heap.emalloc(@sizeOf(c.zend_file_handle)).?));
        c.zend_stream_init_filename(fh, filename.ptr);
        return .from(fh);
    }

    /// Release resources and storage for a handle returned by init.
    pub fn deinit(self: *FileHandle) void {
        c.zend_destroy_file_handle(self.ptr());
        heap.efree(self.ptr());
    }

    pub fn setPrimaryScript(self: *FileHandle, value: bool) void {
        self.ptr().primary_script = value;
    }
};

test {
    std.testing.refAllDecls(FileHandle);
}
