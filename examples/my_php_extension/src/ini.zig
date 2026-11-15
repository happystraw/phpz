const std = @import("std");

const phpz = @import("phpz");

const Globals = @import("metrics.zig").Globals;

pub const greeting = phpz.ini.string.new(.{ .name = "my_php_extension.greeting", .default = "Hello", .access = .all });
pub const max_users = phpz.ini.int.new(.{ .name = "my_php_extension.max_users", .default = 100, .access = .system });
pub const debug = phpz.ini.boolean.new(.{
    .name = "my_php_extension.debug",
    .default = false,
    .access = .user,
    .displayer = phpz.ini.displayer(displayDebug),
});

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
    .displayer = phpz.ini.displayer(displayMode),
});

fn displayText(entry: *phpz.c.zend_ini_entry, kind: phpz.ini.DisplayType) [:0]const u8 {
    const modified = if (comptime @TypeOf(entry.modified) == bool) entry.modified else entry.modified != 0;
    const value = if (kind == .original and modified) entry.orig_value else entry.value;
    return if (value) |text| phpz.zend.String.from(text).slice() else "";
}

fn displayMode(entry: *phpz.c.zend_ini_entry, kind: phpz.ini.DisplayType) void {
    // Fixed labels are safe for both text and HTML phpinfo output.
    const label: [:0]const u8 = if (std.mem.eql(u8, displayText(entry, kind), "fast")) "MODE[fast]" else "MODE[safe]";
    _ = phpz.printf("%s", .{label.ptr});
}

fn displayDebug(entry: *phpz.c.zend_ini_entry, kind: phpz.ini.DisplayType) void {
    const label: [:0]const u8 = if (phpz.ini.parseBool(displayText(entry, kind))) "DEBUG[on]" else "DEBUG[off]";
    _ = phpz.printf("%s", .{label.ptr});
}

pub const definitions = &.{ greeting, max_users, debug, mode };
