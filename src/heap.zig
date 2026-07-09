const std = @import("std");
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

const c = @import("root.zig").c;
const zend = @import("zend.zig");

/// A wrapper around the PHP Memory Manager API which supports the full `Allocator` interface.
///
/// This allocator delegates all memory operations to PHP's internal memory manager (`emalloc`,
/// `erealloc`, `efree`), ensuring that allocations are tracked and managed within the PHP
/// request lifecycle.
///
/// In debug mode (ZEND_DEBUG=1), the allocator resolves the caller's return address to a
/// multi-frame source location trace using DWARF debug info, so PHP's leak reports point to
/// the actual allocation site rather than this file.
///
/// `emalloc` / `erealloc` never return `null` on failure. Instead, PHP raises a
/// fatal error and performs a Zend bailout. This allocator catches that bailout
/// and reports allocation failure through Zig's allocator `null` path, which is
/// surfaced as `error.OutOfMemory` by `std.mem.Allocator`.
pub const php_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &php_allocator_impl.vtable,
};

const php_allocator_impl = struct {
    comptime {
        if (!@hasDecl(c, "emalloc")) {
            @compileError("Missing emalloc declaration. Please '#include \"Zend/zend_API.h\"'");
        }
    }

    const vtable: Allocator.VTable = .{
        .alloc = alloc,
        .resize = resize,
        .remap = remap,
        .free = free,
    };

    fn alloc(context: *anyopaque, len: usize, alignment: Alignment, return_address: usize) ?[*]u8 {
        _ = context;
        // same as raw c allocator alignment
        std.debug.assert(alignment.compare(.lte, .of(std.c.max_align_t)));

        const Context = struct {
            len: usize,
            return_address: usize,
            result: ?*anyopaque = null,

            fn call(raw: ?*anyopaque) callconv(.c) void {
                const self: *@This() = @ptrCast(@alignCast(raw.?));
                if (comptime c.ZEND_DEBUG == 1) {
                    const src = DebugSourceLocation.resolve(self.return_address);
                    self.result = c._emalloc(self.len, src.file.ptr, @intCast(src.line), null, 0);
                } else {
                    self.result = c.emalloc(self.len);
                }
            }
        };

        var ctx: Context = .{
            .len = len,
            .return_address = return_address,
        };
        zend.tryCatchRaw(Context.call, &ctx) catch return null;
        return @ptrCast(ctx.result);
    }

    fn resize(context: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, return_address: usize) bool {
        _ = context;
        _ = memory;
        _ = alignment;
        _ = new_len;
        _ = return_address;
        return false;
    }

    fn remap(context: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, return_address: usize) ?[*]u8 {
        _ = context;
        _ = alignment;

        const Context = struct {
            memory: []u8,
            new_len: usize,
            return_address: usize,
            result: ?*anyopaque = null,

            fn call(raw: ?*anyopaque) callconv(.c) void {
                const self: *@This() = @ptrCast(@alignCast(raw.?));
                if (comptime c.ZEND_DEBUG == 1) {
                    const src = DebugSourceLocation.resolve(self.return_address);
                    self.result = c._erealloc(self.memory.ptr, self.new_len, src.file.ptr, @intCast(src.line), null, 0);
                } else {
                    self.result = c.erealloc(self.memory.ptr, self.new_len);
                }
            }
        };

        var ctx: Context = .{
            .memory = memory,
            .new_len = new_len,
            .return_address = return_address,
        };
        zend.tryCatchRaw(Context.call, &ctx) catch return null;
        return @ptrCast(ctx.result);
    }

    fn free(context: *anyopaque, memory: []u8, alignment: Alignment, return_address: usize) void {
        _ = context;
        _ = alignment;
        if (comptime c.ZEND_DEBUG == 1) {
            const src = DebugSourceLocation.resolve(return_address);
            c._efree(memory.ptr, src.file.ptr, @intCast(src.line), null, 0);
        } else {
            c.efree(memory.ptr);
        }
    }

    test {
        std.testing.refAllDecls(@This());
    }
};

/// Resolves return addresses to `file:line:column` traces via DWARF debug info.
/// When ZEND_DEBUG != 1, this is `void` and all related code is eliminated at
/// compile time.
///
/// Each frame in the trace is labeled `#N: file:line:column` and separated by
/// newlines. The `line` field carries the first non-stdlib frame's line number,
/// which PHP displays as `(NN)` in leak reports.
const DebugSourceLocation = if (c.ZEND_DEBUG == 1) struct {
    /// Null-terminated trace string, persisted in `storage` arena.
    file: [:0]const u8,
    /// Line number of the first non-stdlib frame (shown as `(NN)` by PHP).
    line: u64,

    /// Sent back when stack capture or DWARF resolution fails.
    const unknown: DebugSourceLocation = .{ .file = "", .line = 0 };

    /// How many stack frames to unwind (configurable via `Phpz.Options`).
    const max_trace_depth = @import("phpz_options").debug_leak_trace_frames;
    /// Stack buffer size for building the formatted trace string.
    const max_trace_buf_len = 2048;

    /// Persistent storage for trace strings. PHP stores the filename pointer
    /// in allocation headers, so it must outlive the allocation.
    var storage: std.heap.ArenaAllocator = .init(std.heap.page_allocator);

    /// Cache: return address → trace. Avoids repeated DWARF resolution
    /// for allocations from the same call site (e.g. inside loops).
    var cache: std.AutoArrayHashMapUnmanaged(usize, DebugSourceLocation) = .{};

    /// Captures a stack trace starting from `return_address`. Results are
    /// cached by return address to avoid repeated DWARF resolution.
    fn resolve(return_address: usize) DebugSourceLocation {
        if (cache.get(return_address)) |cached| return cached;
        var addr_buf: [max_trace_depth]usize = undefined;
        const st = std.debug.captureCurrentStackTrace(.{ .first_address = return_address }, &addr_buf);
        if (st.return_addresses.len == 0) return .unknown;

        var buf: [max_trace_buf_len]u8 = undefined;
        var pos: usize = 0;
        const line = writeTrace(&buf, &pos, st.return_addresses);
        if (pos == 0) return .unknown;

        const persisted = storage.allocator().dupeSentinel(u8, buf[0..pos], 0) catch return .unknown;
        const result: DebugSourceLocation = .{ .file = persisted, .line = line };
        cache.put(storage.allocator(), return_address, result) catch {};
        return result;
    }

    /// Resolves each address to a `Symbol` via DWARF and writes formatted
    /// frames into `buf`. Returns the line number of the first non-stdlib
    /// frame (0 if none resolved).
    fn writeTrace(buf: *[max_trace_buf_len]u8, pos: *usize, addresses: []const usize) u64 {
        const di = std.debug.getSelfDebugInfo() catch return 0;
        const io = std.Options.debug_io;

        var first_file: []const u8 = "";
        var first_line: u64 = 0;

        const allocator = std.debug.getDebugInfoAllocator();

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();

        for (addresses, 0..) |addr, i| {
            defer _ = arena.reset(.retain_capacity);

            var symbols = std.ArrayList(std.debug.Symbol).initCapacity(allocator, 1) catch break;
            defer symbols.deinit(allocator);

            di.getSymbols(io, allocator, arena.allocator(), addr, false, &symbols) catch continue;
            if (symbols.items.len == 0) continue;

            if (symbols.items[0].source_location) |sl| {
                if (first_line == 0 and !isStdLibPath(sl.file_name)) {
                    first_line = sl.line;
                    first_file = allocator.dupe(u8, std.fs.path.basename(sl.file_name)) catch "";
                }
                const written = std.fmt.bufPrint(buf[pos.*..], "#{d}: {s}:{d}:{d}\n", .{ i, sl.file_name, sl.line, sl.column }) catch break;
                pos.* += written.len;
            } else {
                const written = std.fmt.bufPrint(buf[pos.*..], "#{d}: 0x{x}\n", .{ i, addr }) catch break;
                pos.* += written.len;
            }
        }
        if (first_file.len != 0) {
            defer allocator.free(first_file);
            const written = std.fmt.bufPrint(buf[pos.*..], "> {s}", .{first_file}) catch return first_line;
            pos.* += written.len;
        }
        return first_line;
    }

    /// Returns true if `path` is inside the Zig standard library directory.
    /// Checks for `lib/std/` as consecutive path components (Unix: `/lib/std/`,
    /// Windows: `\lib\std\`).
    fn isStdLibPath(path: []const u8) bool {
        return std.mem.indexOf(u8, path, "/lib/std/") != null or
            std.mem.indexOf(u8, path, "\\lib\\std\\") != null;
    }

    test {
        _ = &resolve;
        _ = &writeTrace;
        _ = &isStdLibPath;
    }
} else void;
