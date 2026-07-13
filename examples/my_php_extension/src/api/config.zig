const phpz = @import("phpz");

const ini = @import("../ini.zig");

/// PHP: MyPHPExt\Config::greeting(): string
fn greeting(ctx: phpz.Ctx) void {
    ctx.ret.set(.string, ini.greeting.get());
}

/// PHP: MyPHPExt\Config::maxUsers(): int
fn maxUsers(ctx: phpz.Ctx) void {
    ctx.ret.set(.int, ini.max_users.get());
}

/// PHP: MyPHPExt\Config::debugEnabled(): bool
fn debugEnabled(ctx: phpz.Ctx) void {
    ctx.ret.set(.bool, ini.debug.get());
}

/// PHP: MyPHPExt\Config::mode(): string
fn mode(ctx: phpz.Ctx) void {
    ctx.ret.set(.string, @tagName(ini.mode.get()));
}

pub const Class = phpz.SimpleClass("MyPHPExt\\Config", void);

comptime {
    Class.method("greeting", greeting);
    Class.method("maxUsers", maxUsers);
    Class.method("debugEnabled", debugEnabled);
    Class.method("mode", mode);
}
