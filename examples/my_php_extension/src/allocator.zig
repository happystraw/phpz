const std = @import("std");
const builtin = @import("builtin");
const phpz = @import("phpz");

var debug_allocator = if (builtin.mode == .Debug) std.heap.DebugAllocator(.{}).init else {};

pub const gpa = if (builtin.mode == .Debug) debug_allocator.allocator() else phpz.heap.php_allocator;

pub fn deinit() void {
    if (builtin.mode == .Debug) {
        if (debug_allocator.deinit() == .leak) {
            std.log.err("Memory leak!", .{});
        }
    }
}
