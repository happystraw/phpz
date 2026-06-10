const std = @import("std");

const c = @import("root.zig").c;

/// Callback signature for on_modify.
pub const OnModifyFn = *const fn (entry: *c.zend_ini_entry, new_value: ?*c.zend_string, mh_arg1: ?*anyopaque, mh_arg2: ?*anyopaque, mh_arg3: ?*anyopaque, stage: c_int) callconv(.c) c_int;

/// Where an INI directive can be modified.
pub const Access = enum(u8) {
    system = c.ZEND_INI_SYSTEM,
    user = c.ZEND_INI_USER,
    perdir = c.ZEND_INI_PERDIR,
    all = c.ZEND_INI_ALL,
};

/// Definition for a single INI directive.
pub const Entry = struct {
    name: [:0]const u8,
    value: [:0]const u8,
    access: Access = .all,
    on_modify: ?OnModifyFn = null,
};

/// Comptime helper that builds a null-terminated zend_ini_entry_def array.
pub fn entries(comptime list: []const Entry) [list.len + 1]c.zend_ini_entry_def {
    var arr: [list.len + 1]c.zend_ini_entry_def = undefined;
    for (list, 0..) |entry, i| {
        arr[i] = .{
            .name = entry.name,
            .on_modify = if (entry.on_modify) |cb| @ptrCast(cb) else null,
            .mh_arg1 = null,
            .mh_arg2 = null,
            .mh_arg3 = null,
            .value = entry.value,
            .displayer = null,
            .value_length = @intCast(entry.value.len),
            .name_length = @intCast(entry.name.len),
            .modifiable = @intFromEnum(entry.access),
        };
    }
    arr[list.len] = std.mem.zeroes(c.zend_ini_entry_def);
    return arr;
}

/// Read a global INI value as a string (null if not set).
pub fn get(name: []const u8) ?[]const u8 {
    const str = c.zend_ini_str(name.ptr, @intCast(name.len), false);
    return if (str) |s| s.*.val()[0..s.*.len] else null;
}

/// Read a global INI value as an i64.
pub fn getLong(name: []const u8) i64 {
    return c.zend_ini_long(name.ptr, @intCast(name.len), 0);
}

/// Read a global INI value as an f64.
pub fn getDouble(name: []const u8) f64 {
    return c.zend_ini_double(name.ptr, @intCast(name.len), 0);
}

/// OnModify callback for string values: updates a global `[]const u8`.
pub fn onUpdateString(comptime global: *[]const u8) OnModifyFn {
    return struct {
        fn cb(_: *c.zend_ini_entry, new_value: ?*c.zend_string, _: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque, _: c_int) callconv(.c) c_int {
            if (new_value) |nv| {
                global.* = nv.*.val()[0..nv.*.len];
            }
            return c.SUCCESS;
        }
    }.cb;
}

/// OnModify callback for i64 values.
pub fn onUpdateLong(comptime global: *i64) OnModifyFn {
    return struct {
        fn cb(_: *c.zend_ini_entry, new_value: ?*c.zend_string, _: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque, _: c_int) callconv(.c) c_int {
            if (new_value) |nv| {
                const s = nv.*.val()[0..nv.*.len];
                global.* = std.fmt.parseInt(i64, s, 10) catch return c.FAILURE;
            }
            return c.SUCCESS;
        }
    }.cb;
}

/// OnModify callback for f64 values.
pub fn onUpdateDouble(comptime global: *f64) OnModifyFn {
    return struct {
        fn cb(_: *c.zend_ini_entry, new_value: ?*c.zend_string, _: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque, _: c_int) callconv(.c) c_int {
            if (new_value) |nv| {
                const s = nv.*.val()[0..nv.*.len];
                global.* = std.fmt.parseFloat(f64, s) catch return c.FAILURE;
            }
            return c.SUCCESS;
        }
    }.cb;
}

/// OnModify callback for bool values.
pub fn onUpdateBool(comptime global: *bool) OnModifyFn {
    return struct {
        fn cb(_: *c.zend_ini_entry, new_value: ?*c.zend_string, _: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque, _: c_int) callconv(.c) c_int {
            if (new_value) |nv| {
                const s = nv.*.val()[0..nv.*.len];
                if (s.len == 0) {
                    global.* = false;
                } else {
                    global.* = std.mem.eql(u8, s, "1") or
                        std.ascii.eqlIgnoreCase(s, "on") or
                        std.ascii.eqlIgnoreCase(s, "yes") or
                        std.ascii.eqlIgnoreCase(s, "true");
                }
            }
            return c.SUCCESS;
        }
    }.cb;
}
