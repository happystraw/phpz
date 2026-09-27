const phpz = @import("phpz");
const ini = @import("../ini.zig");

/// PHP: MyPHPExt\Config::greeting(): string
pub fn greeting() ![]const u8 {
    return try ini.greeting.get();
}

/// PHP: MyPHPExt\Config::maxUsers(): int
pub fn maxUsers() !i64 {
    return try ini.max_users.get();
}

/// PHP: MyPHPExt\Config::debugEnabled(): bool
pub fn debugEnabled() !bool {
    return try ini.debug.get();
}

/// PHP: MyPHPExt\Config::mode(): string
pub fn mode() ![]const u8 {
    return @tagName(try ini.mode.get());
}

pub const Class = phpz.Class("MyPHPExt\\Config", @This(), .{});
