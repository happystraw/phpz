const phpz = @import("phpz");

const ini = @import("../ini.zig");

/// PHP: MyPHPExt\Config::greeting(): string
pub fn greeting(ctx: phpz.Ctx) void {
    ctx.ret.set(.string, ini.greeting.get());
}

/// PHP: MyPHPExt\Config::maxUsers(): int
pub fn maxUsers(ctx: phpz.Ctx) void {
    ctx.ret.set(.int, ini.max_users.get());
}

/// PHP: MyPHPExt\Config::debugEnabled(): bool
pub fn debugEnabled(ctx: phpz.Ctx) void {
    ctx.ret.set(.bool, ini.debug.get());
}

/// PHP: MyPHPExt\Config::mode(): string
pub fn mode(ctx: phpz.Ctx) void {
    ctx.ret.set(.string, @tagName(ini.mode.get()));
}

pub const Class = phpz.Class("MyPHPExt\\Config", @This(), .{});
