const std = @import("std");

const c = @import("root.zig").c;
const globals = @import("globals.zig");
const zend = @import("zend.zig");

// Types

/// Callback invoked during INI initialization, modification, and restoration.
/// `stage` identifies the lifecycle phase; `new_value` may be null.
pub const OnModifyFn = *const fn (entry: *c.zend_ini_entry, new_value: ?*c.zend_string, mh_arg1: ?*anyopaque, mh_arg2: ?*anyopaque, mh_arg3: ?*anyopaque, stage: c_int) callconv(.c) c_int;

/// Where an INI directive may be modified.
pub const Access = enum(c_int) {
    system = c.ZEND_INI_SYSTEM,
    user = c.ZEND_INI_USER,
    perdir = c.ZEND_INI_PERDIR,
    all = c.ZEND_INI_ALL,
    _,
};

/// INI update stage passed to Zend's alter-ini API.
pub const Stage = enum(c_int) {
    startup = c.ZEND_INI_STAGE_STARTUP,
    shutdown = c.ZEND_INI_STAGE_SHUTDOWN,
    activate = c.ZEND_INI_STAGE_ACTIVATE,
    deactivate = c.ZEND_INI_STAGE_DEACTIVATE,
    runtime = c.ZEND_INI_STAGE_RUNTIME,
    htaccess = c.ZEND_INI_STAGE_HTACCESS,
    _,
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
/// `get()` reads the current thread's bound globals field when `.bind` is set;
/// otherwise it reads and parses the Zend INI value. Parsers should avoid side
/// effects and return scalars or borrowed views, not owned resources.
/// Optional `.bind = Globals.iniField("field")` stores parsed values in module
/// globals. Zend updates and restores that field through the INI callback.
/// String views borrow Zend's INI storage and may become invalid when the
/// directive is changed, restored, or destroyed.
///
/// ```zig
/// const Mode = enum { safe, fast };
///
/// const mode = phpz.ini.Typed(Mode).new(.{
///     .name = "ext.mode",
///     .default_text = "safe",
///     .access = .all,
///     .parse = parseMode,
///     .format = formatMode,
/// });
/// ```
pub fn Typed(comptime T: type) type {
    return struct {
        pub const ParseFn = fn ([:0]const u8) anyerror!T;
        pub const ParseWithEntryFn = fn (*c.zend_ini_entry, [:0]const u8) anyerror!T;
        pub const FormatFn = fn (T, []u8) anyerror![]const u8;

        pub const Config = struct {
            name: [:0]const u8,
            default_text: [:0]const u8,
            access: Access,
            parse: ?*const ParseFn = null,
            parse_with_entry: ?*const ParseWithEntryFn = null,
            format: ?*const FormatFn = null,
            bind: ?type = null,
        };

        pub fn new(comptime cfg: Config) type {
            comptime {
                if ((cfg.parse == null) == (cfg.parse_with_entry == null))
                    @compileError("ini.Typed requires exactly one of .parse or .parse_with_entry");
                if (cfg.bind) |binding| {
                    if (binding.Value != T) @compileError("INI bound field type must match " ++ @typeName(T));
                }
            }
            return struct {
                pub const Globals: ?type = if (cfg.bind) |binding| binding.Globals else null;

                /// Read after INI initialization. Bound values are not parsed again.
                /// Unbound reads may return IniNotFound or a parser error, and
                /// integer parsing may emit Zend warnings for invalid quantities.
                pub fn get() !T {
                    if (comptime cfg.bind) |binding| return binding.ptr().*;
                    const entry = globals.executor().iniDirectives().findPtr(c.zend_ini_entry, cfg.name) orelse return error.IniNotFound;
                    return parse(entry, if (entry.value) |value| zend.String.from(value).slice() else "");
                }

                pub fn set(new_value: T) SetError!void {
                    return setWith(new_value, .{});
                }

                pub fn setWith(new_value: T, opts: SetOptions) SetError!void {
                    const format = cfg.format orelse @compileError(
                        "ini.Typed(" ++ @typeName(T) ++ ").new(...) requires .format to use set()",
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

                pub fn iniDef() c.zend_ini_entry_def {
                    return .{
                        .name = cfg.name,
                        .on_modify = @ptrCast(&onModify),
                        .mh_arg1 = null,
                        .mh_arg2 = null,
                        .mh_arg3 = null,
                        .value = cfg.default_text,
                        .displayer = null,
                        .value_length = @intCast(cfg.default_text.len),
                        .name_length = @intCast(cfg.name.len),
                        .modifiable = @backingInt(cfg.access),
                    };
                }

                fn onModify(entry: *c.zend_ini_entry, new_value: ?*c.zend_string, _: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque, _: c_int) callconv(.c) c_int {
                    const text = if (new_value) |nv| zend.String.from(nv).slice() else "";
                    const parsed = parse(entry, text) catch return c.FAILURE;
                    if (cfg.bind) |binding| binding.ptr().* = parsed;
                    return c.SUCCESS;
                }

                fn parse(entry: *c.zend_ini_entry, text: [:0]const u8) !T {
                    if (comptime cfg.parse_with_entry) |f| return f(entry, text);
                    if (comptime cfg.parse) |f| return f(text);
                    @compileError(
                        "ini.Typed(" ++ @typeName(T) ++ ").new(...) requires .parse or .parse_with_entry",
                    );
                }
            };
        }
    };
}

fn ScalarConfig(comptime T: type) type {
    return struct {
        name: [:0]const u8,
        default: T,
        access: Access,
        bind: ?type = null,
    };
}

/// Length-preserving views of Zend INI strings.
pub const string = struct {
    pub fn new(comptime cfg: ScalarConfig([:0]const u8)) type {
        return Typed([:0]const u8).new(.{
            .name = cfg.name,
            .default_text = cfg.default,
            .access = cfg.access,
            .bind = cfg.bind,
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

/// Integer directives use Zend's OnUpdateLong quantity rules, including K/M/G
/// suffixes, native warnings, and compatibility results for invalid input.
pub const int = struct {
    pub fn new(comptime cfg: ScalarConfig(i64)) type {
        return Typed(i64).new(.{
            .name = cfg.name,
            .default_text = std.fmt.comptimePrint("{d}", .{cfg.default}),
            .access = cfg.access,
            .bind = cfg.bind,
            .parse_with_entry = parse,
            .format = format,
        });
    }

    fn parse(entry: *c.zend_ini_entry, text: [:0]const u8) !i64 {
        const zstr = zend.String.init(text, false);
        defer zstr.release();
        return c.zend_ini_parse_quantity_warn(zstr.ptr(), entry.name);
    }

    fn format(value: i64, buffer: []u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "{d}", .{value});
    }
};

/// Floating-point directives use Zend's OnUpdateReal numeric-prefix rules.
pub const float = struct {
    pub fn new(comptime cfg: ScalarConfig(f64)) type {
        return Typed(f64).new(.{
            .name = cfg.name,
            .default_text = std.fmt.comptimePrint("{e}", .{cfg.default}),
            .access = cfg.access,
            .bind = cfg.bind,
            .parse = parse,
            .format = format,
        });
    }

    fn parse(text: [:0]const u8) !f64 {
        return c.zend_strtod(text.ptr, null);
    }

    fn format(value: f64, buffer: []u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "{e}", .{value});
    }
};

/// Boolean directives use zend_ini_parse_bool without additional trimming.
pub const boolean = struct {
    pub fn new(comptime cfg: ScalarConfig(bool)) type {
        return Typed(bool).new(.{
            .name = cfg.name,
            .default_text = if (cfg.default) "1" else "0",
            .access = cfg.access,
            .bind = cfg.bind,
            .parse = parse,
            .format = format,
        });
    }

    fn parse(text: [:0]const u8) !bool {
        return parseBool(text);
    }

    fn format(value: bool, _: []u8) ![]const u8 {
        return if (value) "1" else "0";
    }
};

// Custom — free-form INI entry

/// INI entry with a custom callback. `args` is a tuple of 0–3 opaque pointers
/// forwarded as mh_arg1/mh_arg2/mh_arg3; omitted arguments become null.
///
/// ```zig
/// const mode = ini.custom("ext.mode", "default", .all, myCallback, .{&ctx});
/// ```
pub fn custom(
    comptime name: [:0]const u8,
    comptime default_value: [:0]const u8,
    comptime access: Access,
    comptime on_modify: ?OnModifyFn,
    comptime args: anytype,
) type {
    const mh = unpackMhArgs(args);
    return struct {
        pub fn iniDef() c.zend_ini_entry_def {
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
                .modifiable = @backingInt(access),
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
/// const greeting = ini.string.new(.{ .name = "ext.greeting", .default = "Hello", .access = .all });
/// const max      = ini.int.new(.{ .name = "ext.max", .default = 100, .access = .system });
/// const debug    = ini.boolean.new(.{ .name = "ext.debug", .default = false, .access = .user });
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

/// Borrow the current thread's INI string, preserving embedded NUL bytes.
/// Missing directives return null; an existing directive with no value returns "".
/// The view may become invalid when the directive is changed, restored, or destroyed.
pub fn get(name: []const u8) ?[:0]const u8 {
    const entry = globals.executor().iniDirectives().findPtr(c.zend_ini_entry, name) orelse return null;
    return if (entry.value) |s| zend.String.from(s).slice() else "";
}

/// Read through zend_ini_long (base-0 integer parsing, without K/M/G expansion).
/// Missing directives return 0. Quantity parsing is provided by int.new().
pub fn getInt(name: []const u8) i64 {
    return c.zend_ini_long(name.ptr, @intCast(name.len), 0);
}

/// Read through zend_ini_double, using zend_strtod. Missing directives return 0.
pub fn getFloat(name: []const u8) f64 {
    return c.zend_ini_double(name.ptr, @intCast(name.len), 0);
}

/// Read through zend_ini_parse_bool. Missing or null values return false.
pub fn getBool(name: []const u8) bool {
    const entry = globals.executor().iniDirectives().findPtr(c.zend_ini_entry, name) orelse return false;
    return if (entry.value) |value| c.zend_ini_parse_bool(value) else false;
}

/// Parse through zend_ini_parse_bool: exact case-insensitive "true"/"on"/"yes"
/// matches are true; other values use atoi != 0. No additional trimming is applied.
pub fn parseBool(s: []const u8) bool {
    const value = zend.String.init(s, false);
    defer value.release();
    return c.zend_ini_parse_bool(value.ptr());
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
                "pass a value returned by phpz.ini.string/int/float/boolean/Typed.new(...) or phpz.ini.custom(...)",
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
    const zname = zend.String.init(name, false);
    defer zname.release();

    const result = if (opts.force)
        c.zend_alter_ini_entry_chars_ex(zname.ptr(), value.ptr, value.len, @backingInt(opts.modify), @backingInt(opts.stage), 1)
    else
        c.zend_alter_ini_entry_chars(zname.ptr(), value.ptr, value.len, @backingInt(opts.modify), @backingInt(opts.stage));
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
    const greeting = string.new(.{ .name = "test.greeting", .default = "Hello", .access = .all });
    const max = int.new(.{ .name = "test.max", .default = 100, .access = .system });
    const debug = boolean.new(.{ .name = "test.debug", .default = false, .access = .user });
    const mode = Typed(Mode).new(.{
        .name = "test.mode",
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
        .modifiable = @backingInt(Access.all),
    };
    _ = collect(.{ raw, &raw });
    _ = &entryDef;
    _ = &alter;
}
