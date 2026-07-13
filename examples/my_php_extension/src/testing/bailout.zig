const phpz = @import("phpz");

fn exhaustPhpAllocator(scope_defer: *bool, cleanup_defer: *bool, freed_blocks: *usize) !void {
    const allocator = phpz.heap.php_allocator;

    defer scope_defer.* = true;

    var blocks: [64][]u8 = undefined;
    var count: usize = 0;
    defer {
        for (blocks[0..count]) |block| allocator.free(block);
        freed_blocks.* = count;
        cleanup_defer.* = true;
    }

    while (count < blocks.len) : (count += 1) {
        const block = try allocator.alloc(u8, 1024 * 1024);
        block[0] = @intCast(count);
        block[block.len - 1] = @intCast(count);
        blocks[count] = block;
    }
}

/// PHP: MyPHPExt\Test\allocatorBailout(): array
fn allocatorBailout(ctx: phpz.Ctx) !void {
    _ = try ctx.call.expectArgs(&.{}, {});

    var scope_defer = false;
    var cleanup_defer = false;
    var freed_blocks: usize = 0;
    var out_of_memory = false;

    exhaustPhpAllocator(&scope_defer, &cleanup_defer, &freed_blocks) catch |err| switch (err) {
        error.OutOfMemory => out_of_memory = true,
    };

    var result = phpz.Zval.Array.empty(ctx.ret.ptr());
    result.set(.bool, "out_of_memory", out_of_memory);
    result.set(.bool, "scope_defer", scope_defer);
    result.set(.bool, "cleanup_defer", cleanup_defer);
    result.set(.bool, "freed_blocks", freed_blocks > 0);
}

comptime {
    phpz.function("MyPHPExt\\Test\\allocatorBailout", allocatorBailout);
}
