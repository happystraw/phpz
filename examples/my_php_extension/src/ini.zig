const phpz = @import("phpz");

var greeting: []const u8 = "Hello";
var max_users: i64 = 100;
var debug_enabled: bool = false;

pub const entries = [_]phpz.ini.Entry{
    .{
        .name = "my_php_extension.greeting",
        .value = "Hello",
        .access = .all,
        .on_modify = phpz.ini.onUpdateString(&greeting),
    },
    .{
        .name = "my_php_extension.max_users",
        .value = "100",
        .access = .system,
        .on_modify = phpz.ini.onUpdateLong(&max_users),
    },
    .{
        .name = "my_php_extension.debug",
        .value = "0",
        .access = .user,
        .on_modify = phpz.ini.onUpdateBool(&debug_enabled),
    },
};
