const std = @import("std");
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

const c = @import("root.zig").c;

/// A wrapper around the PHP Memory Manager API which supports the full `Allocator` interface.
///
/// This allocator delegates all memory operations to PHP's internal memory manager (`emalloc`,
/// `erealloc`, `efree`), ensuring that allocations are tracked and managed within the PHP
/// request lifecycle.
///
/// **Development note:** During development(c.ZEND_DEBUG=1), prefer `std.heap.DebugAllocator` over this allocator.
/// When leaks occur, this allocator cannot report the actual call-site location — the source
/// information passed to PHP's debug memory API (`_emalloc`, `_efree`, etc.) always points to
/// this file rather than the caller, making leak reports difficult to act on.
/// See: https://github.com/ziglang/zig/issues/23512
///
/// **Warning:** `emalloc` never returns `null` on failure. Instead it calls `zend_mm_safe_error()`
/// which invokes `zend_error_noreturn(E_ERROR, ...)` — a `ZEND_NORETURN` function that terminates
/// script execution without returning to the C caller. This means Zig's `defer`/`errdefer` and any
/// pending cleanup will be silently skipped. Zig code using this allocator must not hold resources
/// that require deterministic cleanup across allocation boundaries.
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

    // inline fn getDebugSourceLocation(return_address: usize) std.debug.SourceLocation {
    //     const io = std.Options.debug_io;
    //     const debug_info = std.debug.getSelfDebugInfo() catch |err| {
    //         std.debug.print("Unable to get debug info: {s}\n", .{@errorName(err)});
    //         return .{ .line = 0, .column = 0, .file_name = "unknown" };
    //     };
    //     // defer debug_info.deinit(io);
    //     const symbol = debug_info.getSymbol(io, return_address) catch |err| {
    //         std.debug.print("Unable to get symbol for address {x}: {s}\n", .{ return_address, @errorName(err) });
    //         return .{ .line = 0, .column = 0, .file_name = "unknown" };
    //     };
    //
    //     return symbol.source_location orelse .{ .line = 0, .column = 0, .file_name = "unknown" };
    // }

    const vtable: Allocator.VTable = .{
        .alloc = alloc,
        .resize = resize,
        .remap = remap,
        .free = free,
    };

    fn alloc(context: *anyopaque, len: usize, alignment: Alignment, return_address: usize) ?[*]u8 {
        _ = context;
        _ = return_address;
        // same as raw c allocator alignment
        std.debug.assert(alignment.compare(.lte, .of(std.c.max_align_t)));
        if (comptime c.ZEND_DEBUG == 1) {
            const src = @src();
            return @ptrCast(c._emalloc(len, src.file.ptr, src.line, null, 0));
        } else {
            return @ptrCast(c.emalloc(len));
        }
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
        _ = return_address;
        if (comptime c.ZEND_DEBUG == 1) {
            const src = @src();
            return @ptrCast(c._erealloc(memory.ptr, new_len, src.file.ptr, src.line, null, 0));
        } else {
            return @ptrCast(c.erealloc(memory.ptr, new_len));
        }
    }

    fn free(context: *anyopaque, memory: []u8, alignment: Alignment, return_address: usize) void {
        _ = context;
        _ = alignment;
        _ = return_address;
        if (comptime c.ZEND_DEBUG == 1) {
            const src = @src();
            c._efree(memory.ptr, src.file.ptr, src.line, null, 0);
        } else {
            c.efree(memory.ptr);
        }
    }

    test {
        std.testing.refAllDecls(@This());
    }
};
