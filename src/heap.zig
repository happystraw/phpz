/// A wrapper around the PHP Memory Manager API which supports the full `Allocator` interface.
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

    /// NOTE: ZEND_DEBUG=1 emalloc/erealloc/efree macros lose file/line tracking when wrapped in Zig.
    /// Please use `std.heap.DebugAllocator` for debugging purposes.
    /// https://github.com/ziglang/zig/issues/23512
    const debug = c.ZEND_DEBUG == 1;
    inline fn debug_emalloc(size: usize) ?*anyopaque {
        const src = @src();
        return c._emalloc(size, src.file.ptr, src.line, null, 0);
    }
    inline fn debug_erealloc(ptr: *anyopaque, size: usize) ?*anyopaque {
        const src = @src();
        return c._erealloc(ptr, size, src.file.ptr, src.line, null, 0);
    }
    inline fn debug_efree(ptr: *anyopaque) void {
        const src = @src();
        c._efree(ptr, src.file.ptr, src.line, null, 0);
    }

    const emalloc = if (debug) debug_emalloc else c.emalloc;
    const erealloc = if (debug) debug_erealloc else c.erealloc;
    const efree = if (debug) debug_efree else c.efree;

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
        return @ptrCast(emalloc(len));
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
        return @ptrCast(erealloc(memory.ptr, new_len));
    }

    fn free(context: *anyopaque, memory: []u8, alignment: Alignment, return_address: usize) void {
        _ = context;
        _ = alignment;
        _ = return_address;
        efree(memory.ptr);
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

const c = @import("root.zig").c;
