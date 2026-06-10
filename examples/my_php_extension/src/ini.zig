const phpz = @import("phpz");

pub const greeting = phpz.ini.string.new("my_php_extension.greeting", "Hello", .all);
pub const max_users = phpz.ini.int.new("my_php_extension.max_users", 100, .system);
pub const debug = phpz.ini.boolean.new("my_php_extension.debug", false, .user);

pub const defs = phpz.ini.collect(.{ greeting, max_users, debug });
