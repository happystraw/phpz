const std = @import("std");
const builtin = @import("builtin");

const c = @import("c.zig").c;

const use_dll_import = builtin.os.tag == .windows and builtin.abi == .msvc;

pub const GlobalAccess = enum { ptr, value };

fn Global(comptime access: GlobalAccess, comptime T: type, comptime name: []const u8) type {
    return switch (access) {
        .ptr => if (use_dll_import) *T else @TypeOf(&@field(c, name)),
        .value => T,
    };
}

pub inline fn global(
    comptime access: GlobalAccess,
    comptime T: type,
    comptime name: []const u8,
) Global(access, T, name) {
    return switch (access) {
        .ptr => if (comptime use_dll_import)
            @extern(*T, .{ .name = name, .is_dll_import = true })
        else
            &@field(c, name),
        .value => if (comptime use_dll_import)
            @extern(*T, .{ .name = name, .is_dll_import = true }).*
        else
            @field(c, name),
    };
}

pub const class = struct {
    fn symbolName(comptime prefix: []const u8, comptime class_name: []const u8, comptime lowercase: bool) []const u8 {
        const name = if (class_name.len > 0 and class_name[0] == '\\') class_name[1..] else class_name;
        if (name.len == 0) @compileError("class entry name cannot be empty");

        comptime var result: [prefix.len + name.len]u8 = undefined;
        inline for (prefix, 0..) |ch, i| {
            result[i] = ch;
        }
        inline for (name, 0..) |ch, i| {
            result[prefix.len + i] = comptime switch (ch) {
                '\\' => '_',
                else => if (lowercase) std.ascii.toLower(ch) else ch,
            };
        }

        const final = result;
        return &final;
    }

    fn symbol(comptime class_name: []const u8) []const u8 {
        return comptime blk: {
            const zend_original = symbolName("zend_ce_", class_name, false);
            if (@hasDecl(c, zend_original)) break :blk zend_original;

            const zend_lowercase = symbolName("zend_ce_", class_name, true);
            if (@hasDecl(c, zend_lowercase)) break :blk zend_lowercase;

            const spl_original = symbolName("spl_ce_", class_name, false);
            if (@hasDecl(c, spl_original)) break :blk spl_original;

            const spl_lowercase = symbolName("spl_ce_", class_name, true);
            if (@hasDecl(c, spl_lowercase)) break :blk spl_lowercase;

            @compileError("class entry symbol not found: " ++ zend_original ++ ", " ++ zend_lowercase ++ ", " ++ spl_original ++ ", or " ++ spl_lowercase);
        };
    }

    pub inline fn rawEntry(comptime name: []const u8) *c.zend_class_entry {
        return global(.value, *c.zend_class_entry, name);
    }

    pub inline fn entry(comptime class_name: []const u8) *c.zend_class_entry {
        return rawEntry(symbol(class_name));
    }
};

pub inline fn executor() *c.zend_executor_globals {
    return @ptrCast(c.phpz_executor_globals());
}

pub inline fn compiler() *c.zend_compiler_globals {
    return @ptrCast(c.phpz_compiler_globals());
}

pub inline fn core() *c.php_core_globals {
    return @ptrCast(c.phpz_core_globals());
}

pub inline fn sapi() *c.sapi_globals_struct {
    return @ptrCast(c.phpz_sapi_globals());
}

pub inline fn file() *c.php_file_globals {
    return @ptrCast(c.phpz_file_globals());
}

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(@This().class);
}
