const std = @import("std");

const c = @import("root.zig").c;

// Types

/// Callback invoked when an INI directive is modified at runtime.
pub const OnModifyFn = *const fn (entry: *c.zend_ini_entry, new_value: ?*c.zend_string, mh_arg1: ?*anyopaque, mh_arg2: ?*anyopaque, mh_arg3: ?*anyopaque, stage: c_int) callconv(.c) c_int;

/// Where an INI directive may be modified.
pub const Access = enum(c_int) {
    system = c.ZEND_INI_SYSTEM,
    user = c.ZEND_INI_USER,
    perdir = c.ZEND_INI_PERDIR,
    all = c.ZEND_INI_ALL,
};

/// INI update stage passed to Zend's alter-ini API.
pub const Stage = enum(c_int) {
    startup = c.ZEND_INI_STAGE_STARTUP,
    shutdown = c.ZEND_INI_STAGE_SHUTDOWN,
    activate = c.ZEND_INI_STAGE_ACTIVATE,
    deactivate = c.ZEND_INI_STAGE_DEACTIVATE,
    runtime = c.ZEND_INI_STAGE_RUNTIME,
    htaccess = c.ZEND_INI_STAGE_HTACCESS,
};

pub const SetOptions = struct {
    modify: Access = .user,
    stage: Stage = .runtime,
    force: bool = false,
};

pub const SetError = error{ AlterIniFailed, FormatIniValueFailed };

// Typed INI declarations

/// Typed custom INI definition factory.
///
/// `parse` converts the Zend INI string into `T` whenever PHP changes the
/// directive. The input is length-bounded and also has a 0 sentinel at `len`.
/// `format` is optional; provide it to enable typed `set(T)`.
///
/// ```zig
/// const Mode = enum { safe, fast };
///
/// const mode = phpz.ini.typed(Mode).new(.{
///     .name = "ext.mode",
///     .default = .safe,
///     .default_text = "safe",
///     .access = .all,
///     .parse = parseMode,
///     .format = formatMode,
/// });
/// ```
pub fn typed(comptime T: type) type {
    return struct {
        pub const ParseFn = fn ([:0]const u8) anyerror!T;
        pub const ParseWithEntryFn = fn (*c.zend_ini_entry, [:0]const u8) anyerror!T;
        pub const FormatFn = fn (T, []u8) anyerror![]const u8;

        pub const Config = struct {
            name: [:0]const u8,
            default: T,
            default_text: [:0]const u8,
            access: Access,
            parse: ?*const ParseFn = null,
            parse_with_entry: ?*const ParseWithEntryFn = null,
            format: ?*const FormatFn = null,
        };

        pub fn new(comptime cfg: Config) type {
            return struct {
                var value: T = cfg.default;

                pub inline fn get() T {
                    return value;
                }

                pub fn set(new_value: T) SetError!void {
                    return setWith(new_value, .{});
                }

                pub fn setWith(new_value: T, opts: SetOptions) SetError!void {
                    const format = cfg.format orelse @compileError(
                        "ini.typed(" ++ @typeName(T) ++ ").new(...) requires .format to use set()",
                    );
                    var buffer: [256]u8 = undefined;
                    const text = format(new_value, &buffer) catch return error.FormatIniValueFailed;
                    return alter(cfg.name, text, opts);
                }

                pub fn setText(new_value: []const u8) SetError!void {
                    return setTextWith(new_value, .{});
                }

                pub fn setTextWith(new_value: []const u8, opts: SetOptions) SetError!void {
                    return alter(cfg.name, new_value, opts);
                }

                fn iniDef() c.zend_ini_entry_def {
                    return .{
                        .name = cfg.name,
                        .on_modify = @ptrCast(onModify(&value)),
                        .mh_arg1 = null,
                        .mh_arg2 = null,
                        .mh_arg3 = null,
                        .value = cfg.default_text,
                        .displayer = null,
                        .value_length = @intCast(cfg.default_text.len),
                        .name_length = @intCast(cfg.name.len),
                        .modifiable = @intFromEnum(cfg.access),
                    };
                }

                fn onModify(comptime global: *T) OnModifyFn {
                    return struct {
                        fn handle(entry: *c.zend_ini_entry, new_value: ?*c.zend_string, _: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque, _: c_int) callconv(.c) c_int {
                            if (new_value) |nv| {
                                const text = nv.*.val()[0..nv.*.len :0];
                                global.* = parse(entry, text) catch return c.FAILURE;
                            }
                            return c.SUCCESS;
                        }
                    }.handle;
                }

                fn parse(entry: *c.zend_ini_entry, text: [:0]const u8) anyerror!T {
                    if (comptime cfg.parse_with_entry) |f| return f(entry, text);
                    if (comptime cfg.parse) |f| return f(text);
                    @compileError(
                        "ini.typed(" ++ @typeName(T) ++ ").new(...) requires .parse or .parse_with_entry",
                    );
                }
            };
        }
    };
}

pub const string = struct {
    pub fn new(
        comptime name: [:0]const u8,
        comptime default_value: [:0]const u8,
        comptime access: Access,
    ) type {
        return typed([:0]const u8).new(.{
            .name = name,
            .default = default_value,
            .default_text = default_value,
            .access = access,
            .parse = parse,
            .format = format,
        });
    }

    fn parse(text: [:0]const u8) ![:0]const u8 {
        return text;
    }

    fn format(value: [:0]const u8, _: []u8) ![]const u8 {
        return value;
    }
};

pub const int = struct {
    pub fn new(
        comptime name: [:0]const u8,
        comptime default_value: i64,
        comptime access: Access,
    ) type {
        return typed(i64).new(.{
            .name = name,
            .default = default_value,
            .default_text = std.fmt.comptimePrint("{d}", .{default_value}),
            .access = access,
            .parse_with_entry = parse,
            .format = format,
        });
    }

    fn parse(entry: *c.zend_ini_entry, text: [:0]const u8) !i64 {
        const zstr = c.zend_string_init(text.ptr, text.len, false);
        defer c.zend_string_release(zstr);
        return c.zend_ini_parse_quantity_warn(zstr, entry.*.name);
    }

    fn format(value: i64, buffer: []u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "{d}", .{value});
    }
};

pub const float = struct {
    pub fn new(
        comptime name: [:0]const u8,
        comptime default_value: f64,
        comptime access: Access,
    ) type {
        return typed(f64).new(.{
            .name = name,
            .default = default_value,
            .default_text = std.fmt.comptimePrint("{d}", .{default_value}),
            .access = access,
            .parse = parse,
            .format = format,
        });
    }

    fn parse(text: [:0]const u8) !f64 {
        return std.fmt.parseFloat(f64, std.mem.trim(u8, text, " \t\r\n"));
    }

    fn format(value: f64, buffer: []u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "{d}", .{value});
    }
};

pub const boolean = struct {
    pub fn new(
        comptime name: [:0]const u8,
        comptime default_value: bool,
        comptime access: Access,
    ) type {
        return typed(bool).new(.{
            .name = name,
            .default = default_value,
            .default_text = if (default_value) "1" else "0",
            .access = access,
            .parse = parse,
            .format = format,
        });
    }

    fn parse(text: [:0]const u8) !bool {
        return parseBool(std.mem.trim(u8, text, " \t\r\n"));
    }

    fn format(value: bool, _: []u8) ![]const u8 {
        return if (value) "1" else "0";
    }
};

// Custom — free-form INI entry

/// INI entry with a custom `on_modify` callback. `args` is a tuple of 0–3
/// `?*anyopaque` forwarded as `mh_arg1`/`mh_arg2`/`mh_arg3`.
///
/// ```zig
/// const mode = ini.custom("ext.mode", "default", .all, myCallback, .{&ctx});
/// ```
pub fn custom(
    comptime name: [:0]const u8,
    comptime default_value: [:0]const u8,
    comptime access: Access,
    comptime on_modify: OnModifyFn,
    comptime args: anytype,
) type {
    const mh = unpackMhArgs(args);
    return struct {
        fn iniDef() c.zend_ini_entry_def {
            return .{
                .name = name,
                .on_modify = @ptrCast(on_modify),
                .mh_arg1 = mh[0],
                .mh_arg2 = mh[1],
                .mh_arg3 = mh[2],
                .value = default_value,
                .displayer = null,
                .value_length = @intCast(default_value.len),
                .name_length = @intCast(name.len),
                .modifiable = @intFromEnum(access),
            };
        }
    };
}

// Collect

/// Collects INI declarations into a null-terminated `zend_ini_entry_def` array.
/// Usually `module()` calls this internally for `.ini = &.{ ... }`; use this
/// directly only when integrating with lower-level Zend APIs.
///
/// ```zig
/// const greeting = ini.string.new("ext.greeting", "Hello", .all);
/// const max      = ini.int.new("ext.max", 100, .system);
/// const debug    = ini.boolean.new("ext.debug", false, .user);
///
/// comptime {
///     phpz.module(.{
///         .name = "ext",
///         .ini = &.{ greeting, max, debug },
///     });
/// }
/// ```
///
/// `entries` may also contain raw `c.zend_ini_entry_def` values for low-level
/// integrations.
pub fn collect(comptime entries: anytype) [entries.len + 1]c.zend_ini_entry_def {
    var result: [entries.len + 1]c.zend_ini_entry_def = undefined;
    inline for (entries, 0..) |entry, i| {
        result[i] = entryDef(entry);
    }
    result[entries.len] = std.mem.zeroes(c.zend_ini_entry_def);
    return result;
}

// Runtime getters

/// Reads a global INI value by name (null when not set).
pub fn get(name: []const u8) ?[:0]const u8 {
    const s = c.zend_ini_string(name.ptr, @intCast(name.len), 0);
    return if (s) |p| std.mem.span(p) else null;
}

/// Reads a global INI value as i64.
pub fn getInt(name: []const u8) i64 {
    return c.zend_ini_long(name.ptr, @intCast(name.len), 0);
}

/// Reads a global INI value as f64.
pub fn getFloat(name: []const u8) f64 {
    return c.zend_ini_double(name.ptr, @intCast(name.len), 0);
}

/// Reads a global INI value as bool.
/// Matching `zend_ini_parse_bool`: "true"/"on"/"yes" → true, else atoi ≠ 0.
pub fn getBool(name: []const u8) bool {
    return if (get(name)) |s| parseBool(s) else false;
}

/// Parses a string as bool, matching `zend_ini_parse_bool`:
/// "true"/"on"/"yes" → true, else atoi ≠ 0.
pub fn parseBool(s: []const u8) bool {
    if (std.ascii.eqlIgnoreCase(s, "true") or
        std.ascii.eqlIgnoreCase(s, "on") or
        std.ascii.eqlIgnoreCase(s, "yes")) return true;
    return if (std.fmt.parseInt(i64, s, 10)) |n| n != 0 else |_| false;
}

// on_modify callbacks

/// Updates `*[:0]const u8` on change.
pub fn onUpdateString(comptime global: *[:0]const u8) OnModifyFn {
    return struct {
        fn cb(_: *c.zend_ini_entry, new_value: ?*c.zend_string, _: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque, _: c_int) callconv(.c) c_int {
            if (new_value) |nv| {
                global.* = nv.*.val()[0..nv.*.len :0];
            }
            return c.SUCCESS;
        }
    }.cb;
}

/// Parses as i64 via `zend_ini_parse_quantity_warn` (K/M/G suffixes).
pub fn onUpdateInt(comptime global: *i64) OnModifyFn {
    return struct {
        fn cb(entry: *c.zend_ini_entry, new_value: ?*c.zend_string, _: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque, _: c_int) callconv(.c) c_int {
            if (new_value) |nv| {
                global.* = c.zend_ini_parse_quantity_warn(nv, entry.*.name);
            }
            return c.SUCCESS;
        }
    }.cb;
}

/// Parses as f64 via `zend_strtod`.
pub fn onUpdateFloat(comptime global: *f64) OnModifyFn {
    return struct {
        fn cb(_: *c.zend_ini_entry, new_value: ?*c.zend_string, _: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque, _: c_int) callconv(.c) c_int {
            if (new_value) |nv| {
                global.* = c.zend_strtod(nv.*.val(), null);
            }
            return c.SUCCESS;
        }
    }.cb;
}

/// Parses as bool. Matching `zend_ini_parse_bool`:
/// "true"/"on"/"yes" → true, else atoi ≠ 0.
pub fn onUpdateBool(comptime global: *bool) OnModifyFn {
    return struct {
        fn cb(_: *c.zend_ini_entry, new_value: ?*c.zend_string, _: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque, _: c_int) callconv(.c) c_int {
            if (new_value) |nv| {
                global.* = parseBool(nv.*.val()[0..nv.*.len]);
            }
            return c.SUCCESS;
        }
    }.cb;
}

// Internal

fn entryDef(comptime entry: anytype) c.zend_ini_entry_def {
    const Entry = @TypeOf(entry);
    if (Entry == type) {
        checkEntry(entry);
        return entry.iniDef();
    }
    if (Entry == c.zend_ini_entry_def) return entry;
    if (Entry == *const c.zend_ini_entry_def) return entry.*;

    @compileError(
        "ini.collect entry '" ++ @typeName(Entry) ++ "' must be an INI wrapper type " ++
            "or c.zend_ini_entry_def",
    );
}

fn checkEntry(comptime Entry: type) void {
    if (!@hasDecl(Entry, "iniDef")) {
        @compileError(
            "module .ini entry '" ++ @typeName(Entry) ++ "' has no iniDef() function; " ++
                "pass a value returned by phpz.ini.string/int/float/boolean/typed.new(...) or phpz.ini.custom(...)",
        );
    }

    const ini_def_info = @typeInfo(@TypeOf(Entry.iniDef));
    if (ini_def_info != .@"fn") {
        @compileError("module .ini entry '" ++ @typeName(Entry) ++ "' iniDef declaration is not a function");
    }

    const fn_info = ini_def_info.@"fn";
    if (fn_info.param_types.len != 0 or fn_info.return_type.? != c.zend_ini_entry_def) {
        @compileError("module .ini entry '" ++ @typeName(Entry) ++ "' iniDef must be fn() zend_ini_entry_def");
    }
}

fn alter(comptime name: [:0]const u8, value: []const u8, opts: SetOptions) SetError!void {
    const zname = c.zend_string_init(name.ptr, name.len, false);
    defer c.zend_string_release(zname);

    const result = if (opts.force)
        c.zend_alter_ini_entry_chars_ex(zname, value.ptr, value.len, @intFromEnum(opts.modify), @intFromEnum(opts.stage), 1)
    else
        c.zend_alter_ini_entry_chars(zname, value.ptr, value.len, @intFromEnum(opts.modify), @intFromEnum(opts.stage));
    if (result != c.SUCCESS) return error.AlterIniFailed;
}

fn unpackMhArgs(comptime args: anytype) [3]?*anyopaque {
    if (args.len > 3) @compileError("custom: at most 3 args (mh_arg1/mh_arg2/mh_arg3)");
    var result: [3]?*anyopaque = .{ null, null, null };
    inline for (args, 0..) |arg, i| result[i] = arg;
    return result;
}

test {
    std.testing.refAllDecls(@This());
    const Mode = enum { safe, fast };
    const ModeIni = struct {
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
    const greeting = string.new("test.greeting", "Hello", .all);
    const max = int.new("test.max", 100, .system);
    const debug = boolean.new("test.debug", false, .user);
    const mode = typed(Mode).new(.{
        .name = "test.mode",
        .default = .safe,
        .default_text = "safe",
        .access = .all,
        .parse = ModeIni.parse,
        .format = ModeIni.format,
    });
    _ = collect(&.{ greeting, max, debug, mode });
    const raw = c.zend_ini_entry_def{
        .name = "test.raw",
        .on_modify = null,
        .mh_arg1 = null,
        .mh_arg2 = null,
        .mh_arg3 = null,
        .value = "raw",
        .displayer = null,
        .value_length = 3,
        .name_length = 8,
        .modifiable = @intFromEnum(Access.all),
    };
    _ = collect(.{ raw, &raw });
    _ = &unpackMhArgs;
    _ = &entryDef;
    _ = &alter;
}
