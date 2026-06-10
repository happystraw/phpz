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

// Define — typed INI declarations

/// Typed INI definition factory. Use via `ini.string`, `ini.int`, etc.
fn define(comptime T: type) type {
    return struct {
        pub fn new(
            comptime name: [:0]const u8,
            comptime default_value: T,
            comptime access: Access,
        ) type {
            return struct {
                pub var value: T = default_value;

                fn iniDef() c.zend_ini_entry_def {
                    const val = formatDefault(T, default_value);
                    return .{
                        .name = name,
                        .on_modify = @ptrCast(onModifyFor(T, &value)),
                        .mh_arg1 = null,
                        .mh_arg2 = null,
                        .mh_arg3 = null,
                        .value = val,
                        .displayer = null,
                        .value_length = @intCast(val.len),
                        .name_length = @intCast(name.len),
                        .modifiable = @intFromEnum(access),
                    };
                }
            };
        }
    };
}

pub const string = define([:0]const u8);
pub const int = define(i64);
pub const float = define(f64);
pub const boolean = define(bool);

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

/// Collects typed INI declarations into a null-terminated `zend_ini_entry_def`
/// array ready for `module()`.
///
/// ```zig
/// const greeting = ini.string.new("ext.greeting", "Hello", .all);
/// const max      = ini.int.new("ext.max", 100, .system);
/// const debug    = ini.boolean.new("ext.debug", false, .user);
///
/// pub const defs = ini.collect(.{ greeting, max, debug });
///
/// comptime {
///     phpz.module(.{
///         .name = "ext",
///         .ini_defs = &defs,
///     });
/// }
/// ```
pub fn collect(comptime defs: anytype) [defs.len + 1]c.zend_ini_entry_def {
    var result: [defs.len + 1]c.zend_ini_entry_def = undefined;
    inline for (defs, 0..) |d, i| {
        result[i] = d.iniDef();
    }
    result[defs.len] = std.mem.zeroes(c.zend_ini_entry_def);
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

fn unpackMhArgs(comptime args: anytype) [3]?*anyopaque {
    if (args.len > 3) @compileError("custom: at most 3 args (mh_arg1/mh_arg2/mh_arg3)");
    var result: [3]?*anyopaque = .{ null, null, null };
    inline for (args, 0..) |arg, i| result[i] = arg;
    return result;
}

fn formatDefault(comptime T: type, comptime val: T) [:0]const u8 {
    return switch (T) {
        [:0]const u8 => val,
        i64, f64 => std.fmt.comptimePrint("{d}", .{val}),
        bool => if (val) "1" else "0",
        else => @compileError("Unsupported INI value type: " ++ @typeName(T)),
    };
}

fn onModifyFor(comptime T: type, comptime ptr: *T) OnModifyFn {
    return switch (T) {
        [:0]const u8 => onUpdateString(ptr),
        i64 => onUpdateInt(ptr),
        f64 => onUpdateFloat(ptr),
        bool => onUpdateBool(ptr),
        else => @compileError("Unsupported INI value type: " ++ @typeName(T)),
    };
}

test {
    std.testing.refAllDecls(@This());
    _ = &unpackMhArgs;
    _ = &formatDefault;
    _ = &onModifyFor;
}
