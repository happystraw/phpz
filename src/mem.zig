comptime {
    // FIXME: ZEND_DEBUG 开启的 PHP emalloc/pemalloc 使用 C 宏展开用于定位分配文件行号检测，
    // 分配器无法直接使用 translate-c 后的 zig 代码，需要一层 C 包装，
    // 但是宏内容（主要是分配位置的文件和行号）会失去参考性。
    if (@hasDecl(phpz.c, "ZEND_DEBUG") and phpz.c.ZEND_DEBUG == 1) {
        @compileError(
            \\ ZEND_DEBUG=1 is not supported: emalloc/pemalloc macros lose file/line tracking when wrapped in Zig.
            \\ Please build PHP with ZEND_DEBUG=0, or use DebugAllocator for debugging purposes.
        );
    }
}

pub const php_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &php_allocator_impl.vtable,
};

const php_allocator_impl = struct {
    comptime {
        if (!@hasDecl(phpz.c, "emalloc")) {
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
        _ = return_address;
        // same as raw c allocator alignment
        std.debug.assert(alignment.compare(.lte, .of(std.c.max_align_t)));
        return @ptrCast(phpz.c.emalloc(len));
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
        return @ptrCast(phpz.c.erealloc(memory.ptr, new_len));
    }

    fn free(context: *anyopaque, memory: []u8, alignment: Alignment, return_address: usize) void {
        _ = context;
        _ = alignment;
        _ = return_address;
        phpz.c.efree(memory.ptr);
    }
};

pub const php_persistent_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &php_persistent_allocator_impl.vtable,
};

const php_persistent_allocator_impl = struct {
    comptime {
        if (!@hasDecl(phpz.c, "pemalloc")) {
            @compileError("Missing pemalloc declaration. Please '#include \"Zend/zend_API.h\"'");
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
        _ = return_address;
        std.debug.assert(alignment.compare(.lte, .of(std.c.max_align_t)));
        // same as raw c allocator alignment
        return @ptrCast(phpz.c.pemalloc(len, 1));
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
        return @ptrCast(phpz.c.perealloc(memory.ptr, new_len, 1));
    }

    fn free(context: *anyopaque, memory: []u8, alignment: Alignment, return_address: usize) void {
        _ = context;
        _ = alignment;
        _ = return_address;
        phpz.c.pefree(memory.ptr, 1);
    }
};

const phpz = @import("root.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;
