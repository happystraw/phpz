const std = @import("std");
const phpz = @import("phpz");

/// PHP: MyPHPExt\Test\serializeValue(mixed $value): string
pub fn serializeValue(value: *phpz.Zval) !*phpz.zend.String {
    return phpz.serialization.serialize(value);
}

/// PHP: MyPHPExt\Test\unserializeValue(string $input, ?array $options = null): mixed
pub fn unserializeValue(ctx: phpz.Ctx, input: []const u8, options: ?phpz.Nullable(*phpz.zend.Array)) !void {
    var settings: phpz.serialization.UnserializeOptions = .{};
    var names: std.ArrayList([]const u8) = .empty;
    defer names.deinit(std.heap.page_allocator);
    if (if (options) |option| option.asOptional() else null) |array| {
        if (array.find("allowed_classes")) |raw| {
            const value = phpz.Zval.from(raw);
            if (value.is(.bool)) {
                settings.allowed_classes = if (value.asUnchecked(.bool)) .all else .none;
            } else {
                const classes = try value.as(.array);
                var iterator = classes.fastIterator();
                while (iterator.next()) |entry| {
                    const name = try phpz.Zval.from(entry.value).as(.string);
                    try names.append(std.heap.page_allocator, name);
                }
                settings.allowed_classes = .{ .only = names.items };
            }
        }
        if (array.find("max_depth")) |raw| {
            settings.max_depth = std.math.cast(usize, try phpz.Zval.from(raw).as(.int)) orelse return error.InvalidMaxDepth;
        }
    }
    try phpz.serialization.unserialize(ctx.retval, input, settings);
}

pub fn checkSerializationOptions() !void {
    const expect = std.testing.expect;
    const Options = phpz.serialization.UnserializeOptions;
    const defaults = try (Options{}).toArray();
    defer defaults.release();
    try expect(defaults.len() == 0);

    const restricted = try (Options{ .allowed_classes = .none, .max_depth = 0 }).toArray();
    defer restricted.release();
    try expect(!try phpz.Zval.from(restricted.find("allowed_classes").?).as(.bool));
    try expect(try phpz.Zval.from(restricted.find("max_depth").?).as(.int) == 0);

    const named = try (Options{ .allowed_classes = .{ .only = &.{ "stdClass", "NativeSerialized" } }, .max_depth = 128 }).toArray();
    defer named.release();
    const names = try phpz.Zval.from(named.find("allowed_classes").?).as(.array);
    try expect(names.len() == 2);
    var iterator = names.fastIterator();
    try std.testing.expectEqualStrings("stdClass", try phpz.Zval.from(iterator.next().?.value).as(.string));
    try std.testing.expectEqualStrings("NativeSerialized", try phpz.Zval.from(iterator.next().?.value).as(.string));
    try expect(try phpz.Zval.from(named.find("max_depth").?).as(.int) == 128);

    const empty = try (Options{ .allowed_classes = .{ .only = &.{} } }).toArray();
    defer empty.release();
    try expect((try phpz.Zval.from(empty.find("allowed_classes").?).as(.array)).len() == 0);
    try std.testing.expectError(error.InvalidMaxDepth, (Options{ .max_depth = std.math.maxInt(usize) }).toArray());
}
