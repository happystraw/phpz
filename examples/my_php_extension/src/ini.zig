const phpz = @import("phpz");
const std = @import("std");

pub const greeting = phpz.ini.string.new("my_php_extension.greeting", "Hello", .all);
pub const max_users = phpz.ini.int.new("my_php_extension.max_users", 100, .system);
pub const debug = phpz.ini.boolean.new("my_php_extension.debug", false, .user);

pub const Mode = enum { safe, fast };

pub const mode = phpz.ini.Typed(Mode).new(.{
    .name = "my_php_extension.mode",
    .default = .safe,
    .default_text = "safe",
    .access = .all,
    .parse = parseMode,
    .format = formatMode,
});

fn parseMode(text: [:0]const u8) !Mode {
    if (std.mem.eql(u8, text, "safe")) return .safe;
    if (std.mem.eql(u8, text, "fast")) return .fast;
    return error.InvalidMode;
}

fn formatMode(value: Mode, _: []u8) ![]const u8 {
    return switch (value) {
        .safe => "safe",
        .fast => "fast",
    };
}
