const std = @import("std");

const phpz = @import("phpz");

const Globals = @import("metrics.zig").Globals;

pub const greeting = phpz.ini.string.new(.{ .name = "my_php_extension.greeting", .default = "Hello", .access = .all });
pub const max_users = phpz.ini.int.new(.{ .name = "my_php_extension.max_users", .default = 100, .access = .system });
pub const debug = phpz.ini.boolean.new(.{ .name = "my_php_extension.debug", .default = false, .access = .user });

pub const Mode = enum {
    safe,
    fast,

    fn parse(text: [:0]const u8) !Mode {
        if (std.mem.eql(u8, text, "safe")) return .safe;
        if (std.mem.eql(u8, text, "fast")) return .fast;
        return error.InvalidMode;
    }

    fn format(value: Mode, _: []u8) ![]const u8 {
        return switch (value) {
            .safe => "safe",
            .fast => "fast",
        };
    }
};

pub const mode = phpz.ini.Typed(Mode).new(.{
    .name = "my_php_extension.mode",
    .default_text = "safe",
    .access = .all,
    .parse = Mode.parse,
    .format = Mode.format,
    .bind = Globals.iniField("mode"),
});

pub const definitions = &.{ greeting, max_users, debug, mode };
