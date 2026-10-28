const std = @import("std");
const phpz = @import("phpz");
const Stream = phpz.Stream;
const Resource = phpz.zend.Resource;
const expect = std.testing.expect;
const expectError = std.testing.expectError;

pub fn checkStreams() !void {
    try checkFreeOptionsLayout();
    try checkFreeOptionsPresets();

    const stream = try Stream.open("php://memory", "w+b", .{ .must_seek = true });
    defer _ = stream.close();
    try expect(Stream.from(stream.ptr()) == stream);
    try expect(!stream.isPersistent());
    try expect(!stream.supportsSync());
    try expect(stream.supportsTruncate());
    try expect(!stream.supportsLock());
    try expectError(error.UnsupportedOperation, stream.lock(.exclusive, true));
    try expectError(error.UnsupportedOperation, stream.unlock());
    try expectError(error.UnsupportedOperation, stream.setBlocking(false));
    try expectError(error.UnsupportedOperation, stream.setReadTimeout(1, 0));
    try expectError(error.UnsupportedOperation, stream.setWriteBuffer(0));
    try expectError(error.InvalidTimeout, stream.setReadTimeout(0, 1_000_000));
    try expectError(error.InvalidTimeout, stream.setReadTimeout(std.math.maxInt(u64), 0));
    try expectError(error.InvalidChunkSize, stream.setChunkSize(0));
    try expectError(error.InvalidChunkSize, stream.setChunkSize(@as(usize, std.math.maxInt(c_int)) + 1));
    const old_chunk = try stream.setChunkSize(1024);
    try expect(old_chunk > 0);
    try expect(try stream.setChunkSize(2048) == 1024);
    try expect(try stream.setChunkSize(1) == 2048);
    try expect(try stream.setChunkSize(std.math.maxInt(c_int)) == 1);
    try expect(try stream.setChunkSize(old_chunk) == std.math.maxInt(c_int));
    try stream.setReadBuffer(0);
    try stream.setReadBuffer(4096);
    try expect(try stream.write("") == 0);
    try expect(try stream.write("a\x00b\nxyz") == 7);
    try expect((try stream.stat()).st_size == 7);
    try stream.flush();
    try expect(stream.tell() == 7);
    try stream.seek(-3, .end);
    try stream.seek(-4, .current);

    var buffer: [16]u8 = undefined;
    try expect(try stream.read(buffer[0..0]) == 0);
    try expect(stream.getLine(buffer[0..0]) == null);
    try expect(stream.getLine(buffer[0..1]) == null);
    try expect(stream.tell() == 0);
    const line = stream.getLine(&buffer) orelse return error.MissingLine;
    try expect(line.ptr == &buffer);
    try expect(std.mem.eql(u8, line, "a\x00b\n"));
    try expect(buffer[line.len] == 0);
    const tail = try stream.readToStr(20);
    defer tail.release();
    try expect(std.mem.eql(u8, tail.slice(), "xyz"));
    const empty = try stream.readToStr(5);
    defer empty.release();
    try expect(empty.len() == 0);
    try expect(stream.getLine(&buffer) == null);
    try expect(stream.eof());

    try stream.seek(0, .start);
    try expect(std.mem.eql(u8, stream.getLine(buffer[0..3]).?, "a\x00"));
    try expect(stream.tell() == 2);
    try stream.truncate(3);
    try stream.seek(0, .end);
    try expect(stream.tell() == 3);
    try stream.seek(0, .start);
    const dest = try Stream.open("php://memory", "w+b", .{});
    defer _ = dest.close();
    var copied: usize = 999;
    try stream.copyTo(dest, 0, &copied);
    try expect(copied == 0 and stream.tell() == 0);
    try stream.copyTo(dest, 2, &copied);
    try expect(copied == 2);
    try stream.copyTo(dest, null, &copied);
    try expect(copied == 1);
    try dest.seek(0, .start);
    try expect(try dest.read(&buffer) == 3);
    try expect(std.mem.eql(u8, buffer[0..3], "a\x00b"));
    try expectError(error.SyncFailed, stream.sync(false));

    const owned = try Stream.open("php://memory", "w+b", .{});
    try expect(owned.free(.close) == 0);
    const closed = try Stream.open("php://memory", "w+b", .{});
    try expect(closed.close() == 0);

    // The PHPT wrapper records the options forwarded to stream_set_option().
    const options_stream = try Stream.open("streamoptions://test", "w+b", .{});
    defer _ = options_stream.close();
    try expect(!options_stream.supportsTruncate());
    try options_stream.setBlocking(false);
    try options_stream.setBlocking(true);
    try options_stream.setReadTimeout(0, 0);
    try options_stream.setReadTimeout(0, 999_999);
    try options_stream.setReadTimeout(2, 345_678);
    try options_stream.setReadBuffer(0);
    try options_stream.setReadBuffer(4096);
    try options_stream.setWriteBuffer(0);
    try options_stream.setWriteBuffer(8192);
}

pub fn checkSocketOptions(stream: *Stream) !void {
    var buffer: [1]u8 = undefined;
    try stream.setReadBuffer(0);
    try stream.setBlocking(false);
    try expect(try stream.read(&buffer) == 0);
    try expect(!stream.eof());

    try stream.setBlocking(true);
    try stream.setReadTimeout(0, 20_000);
    try expectError(error.ReadFailed, stream.read(&buffer));
    // The PHPT checks timed_out and verifies that this borrowed stream recovers.
}

fn checkFileOptions(path: [:0]const u8) !void {
    const first = try Stream.open(path, "r+b", .{});
    defer _ = first.close();
    const second = try Stream.open(path, "r+b", .{});
    defer _ = second.close();
    try expect(first.supportsSync() and first.supportsTruncate() and first.supportsLock());
    try expect((try first.stat()).st_size == 4);
    try expect(first.tell() == 0);
    try first.lock(.shared, false);
    try second.lock(.shared, true);
    try second.unlock();
    try first.unlock();
    try first.lock(.exclusive, false);
    // Windows and flock-based systems lock independently opened handles separately.
    // Other systems may implement PHP locks with process-scoped fcntl locks.
    if (@import("builtin").os.tag == .windows or @hasDecl(phpz.c, "HAVE_FLOCK")) {
        try expectError(error.WouldBlock, second.lock(.exclusive, true));
    }
    try first.unlock();
    try second.lock(.exclusive, true);
    try second.unlock();
    if (@import("builtin").os.tag != .windows) {
        // Native streams return the old blocking mode (including success == 1).
        try first.setBlocking(false);
        try first.setBlocking(true);
    }
}

pub fn openStream(ctx: phpz.Ctx, path: *phpz.zend.String) !void {
    const stream = try Stream.open(path.slice(), "w+b", .{});
    stream.toZval(ctx.retval);
}

pub fn openPersistentStream(ctx: phpz.Ctx, path: *phpz.zend.String) !void {
    const stream = try Stream.open(path.slice(), "r+b", .{ .persistent = true });
    try expect(stream.isPersistent());
    stream.toZval(ctx.retval);
}

// Read PHP's actual registry key instead of depending on a wrapper's ID format.
fn persistentId(stream: *Stream) !*phpz.zend.String {
    const registry = phpz.globals.executor().persistentList();
    var it = registry.fastIterator();
    while (it.next()) |entry| {
        const res = entry.value.value.res;
        if (res.*.type == Stream.persistentResourceTypeId() and res.*.ptr == @as(?*anyopaque, @ptrCast(stream))) {
            return phpz.zend.String.init(entry.key.string, false);
        }
    }
    return error.PersistentStreamNotFound;
}

pub fn checkPersistentStreams(path: *phpz.zend.String) !void {
    try checkFileOptions(path.slice());
    const c = phpz.c;
    try expect(try Stream.fromPersistentId("phpz-missing-stream") == null);
    const collision = "phpz-non-stream";
    _ = c.zend_register_persistent_resource(collision, collision.len, null, -1) orelse return error.RegisterFailed;
    defer phpz.globals.executor().persistentList().delete(collision) catch {};
    try expectError(error.PersistentResourceTypeMismatch, Stream.fromPersistentId(collision));

    const stream = try Stream.open(path.slice(), "r+b", .{ .persistent = true });
    var closed = false;
    defer if (!closed) {
        _ = stream.closePersistent();
    };
    try expect(stream.isPersistent());
    const id = try persistentId(stream);
    defer id.release();
    const found = (try Stream.fromPersistentId(id.slice())) orelse return error.PersistentStreamNotFound;
    var alias = phpz.Zval.raw.init(.undef, {});
    found.toZval(phpz.Zval.from(&alias));
    defer c.zval_ptr_dtor(&alias);
    try expect(found == stream);
    const resource = phpz.Zval.raw.asUnchecked(&alias, .resource);
    try expect(resource.refcount() == 2);
    try expect(try Stream.fromResource(resource) == stream);
    try expect(resource.refcount() == 2);

    const reused = try Stream.open(path.slice(), "r+b", .{ .persistent = true });
    var second_alias = phpz.Zval.raw.init(.undef, {});
    reused.toZval(phpz.Zval.from(&second_alias));
    defer c.zval_ptr_dtor(&second_alias);
    try expect(reused == stream and resource.refcount() == 3);
    const result = stream.closePersistent();
    closed = true;
    try expect(result == 0);
    try expect(resource.typeId() == -1 and resource.refcount() == 2);
    try expect(try Stream.fromPersistentId(id.slice()) == null);

    const reopened = try Stream.open(path.slice(), "r+b", .{ .persistent = true });
    try expect(reopened.closePersistent() == 0);
    try expect(try Stream.fromPersistentId(id.slice()) == null);
    try expectError(error.OpenFailed, Stream.open("php://memory", "w+b", .{ .persistent = true }));
}

pub fn openStreamDir(ctx: phpz.Ctx, path: *phpz.zend.String) !void {
    const stream = try Stream.openDir(path.slice(), .{});
    stream.toZval(ctx.retval);
}

pub fn readStreamDir(ctx: phpz.Ctx, resource: *Stream) void {
    var buffer: Stream.DirBuffer = undefined;
    if (resource.readDir(&buffer)) |name| {
        ctx.ret(.string, name);
    } else ctx.ret(.null, {});
}

pub fn rewindStreamDir(resource: *Stream) !void {
    try resource.rewind();
}

pub fn readStream(resource: *Stream, len: usize) !*phpz.zend.String {
    return resource.readToStr(len);
}

pub fn nullableStream(resource: phpz.Nullable(*Stream)) []const u8 {
    return switch (resource) {
        .null => "null",
        .value => "stream",
    };
}

pub fn optionalStream(resource: ?*Stream) []const u8 {
    return if (resource != null) "stream" else "omitted";
}

pub fn optionalNullableStream(resource: ?phpz.Nullable(*Stream)) []const u8 {
    return nullableStream(resource orelse return "omitted");
}

// The PHPT only supplies streams that permit explicit closure.
pub fn closeStream(resource: *Resource) !i32 {
    const stream = try Stream.fromResource(resource);
    var options: Stream.FreeOptions = if (stream.isPersistent()) .close_persistent else .close;
    options.keep_rsrc = true;
    return stream.free(options);
}

pub fn syncStream(resource: *Resource) !void {
    const stream = try Stream.fromResource(resource);
    try expect(stream.supportsSync());
    try stream.flush();
    try stream.sync(false);
    try stream.sync(true);
}

pub fn checkStreamFailures(source: *Resource, destination: *Resource) !void {
    const failed = try Stream.fromResource(source);
    var buffer: [8]u8 = undefined;
    try expectError(error.ReadFailed, failed.read(&buffer));
    try expectError(error.ReadFailed, failed.readToStr(4));
    try expect(failed.getLine(&buffer) == null);
    try expectError(error.WriteFailed, failed.write("x"));
    try expectError(error.FlushFailed, failed.flush());
    try expectError(error.SeekFailed, failed.seek(0, .start));
    try expectError(error.TruncateFailed, failed.truncate(1));
    try expectError(error.StatFailed, failed.stat());
    try expectError(error.SetOptionFailed, failed.setBlocking(false));
    try expectError(error.SetOptionFailed, failed.setReadTimeout(1, 0));
    try expectError(error.SetOptionFailed, failed.setReadBuffer(0));
    try expectError(error.SetOptionFailed, failed.setWriteBuffer(0));
    // A stale errno must not turn a wrapper's ordinary failure into contention.
    std.c._errno().* = phpz.c.EWOULDBLOCK;
    try expectError(error.LockFailed, failed.lock(.exclusive, true));
    try expectError(error.LockFailed, failed.unlock());

    const memory = try Stream.open("php://memory", "w+b", .{});
    defer _ = memory.close();
    var copied: usize = 999;
    try expectError(error.CopyFailed, failed.copyTo(memory, null, &copied));
    try expect(copied == 0);
    _ = try memory.write("abcd");
    try memory.seek(0, .start);
    const short = try Stream.fromResource(destination);
    copied = 999;
    try expectError(error.CopyFailed, memory.copyTo(short, null, &copied));
    // PHP's failure count is not necessarily the number actually written.
    try expect(copied <= 4);
}

fn checkFreeOptionsLayout() !void {
    try expect(@backingInt(Stream.FreeOptions{}) == 0);
    inline for (.{
        .{ "call_dtor", phpz.c.PHP_STREAM_FREE_CALL_DTOR },
        .{ "release_stream", phpz.c.PHP_STREAM_FREE_RELEASE_STREAM },
        .{ "preserve_handle", phpz.c.PHP_STREAM_FREE_PRESERVE_HANDLE },
        .{ "rsrc_dtor", phpz.c.PHP_STREAM_FREE_RSRC_DTOR },
        .{ "persistent", phpz.c.PHP_STREAM_FREE_PERSISTENT },
        .{ "ignore_enclosing", phpz.c.PHP_STREAM_FREE_IGNORE_ENCLOSING },
        .{ "keep_rsrc", phpz.c.PHP_STREAM_FREE_KEEP_RSRC },
    }) |flag| {
        var options: Stream.FreeOptions = .{};
        @field(options, flag[0]) = true;
        try expect(@backingInt(options) == flag[1]);
    }
}

fn checkFreeOptionsPresets() !void {
    try expect(Stream.FreeOptions.close == Stream.FreeOptions{
        .call_dtor = true,
        .release_stream = true,
    });
    try expect(Stream.FreeOptions.close_casted == Stream.FreeOptions{
        .call_dtor = true,
        .release_stream = true,
        .preserve_handle = true,
    });
    try expect(Stream.FreeOptions.close_persistent == Stream.FreeOptions{
        .call_dtor = true,
        .release_stream = true,
        .persistent = true,
    });
}
