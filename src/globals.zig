const std = @import("std");
const builtin = @import("builtin");

const abi = @import("abi.zig");
const c = @import("c.zig").c;
const Zval = @import("zval.zig").Zval;
const zend = @import("zend.zig");

pub const GlobalAccess = enum { ptr, value };

fn Global(comptime access: GlobalAccess, comptime T: type, comptime name: []const u8) type {
    return switch (access) {
        .ptr => if (abi.use_dll_import) *T else @TypeOf(&@field(c, name)),
        .value => T,
    };
}

pub inline fn global(
    comptime access: GlobalAccess,
    comptime T: type,
    comptime name: []const u8,
) Global(access, T, name) {
    return switch (access) {
        .ptr => if (comptime abi.use_dll_import)
            @extern(*T, .{ .name = name, .is_dll_import = true })
        else
            &@field(c, name),
        .value => if (comptime abi.use_dll_import)
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

pub inline fn executor() *ExecutorGlobals {
    return .from(c.phpz_executor_globals());
}

pub inline fn compiler() *CompilerGlobals {
    return .from(c.phpz_compiler_globals());
}

pub inline fn php() *PhpGlobals {
    return .from(c.phpz_core_globals());
}

pub inline fn sapi() *SapiGlobals {
    return .from(c.phpz_sapi_globals());
}

pub inline fn file() *FileGlobals {
    return .from(c.phpz_file_globals());
}

pub const ExecutorGlobals = opaque {
    pub const Superglobal = enum {
        GET,
        POST,
        COOKIE,
        SERVER,
        ENV,
        FILES,
        REQUEST,

        pub fn name(comptime self: Superglobal) []const u8 {
            return "_" ++ @tagName(self);
        }

        pub inline fn ensureInitialized(comptime self: Superglobal) void {
            const global_name = self.name();
            _ = c.zend_is_auto_global_str(global_name.ptr, global_name.len);
        }
    };

    pub inline fn from(globals: *c.zend_executor_globals) *ExecutorGlobals {
        return @ptrCast(globals);
    }

    pub inline fn ptr(self: *ExecutorGlobals) *c.zend_executor_globals {
        return @ptrCast(@alignCast(self));
    }

    pub inline fn symbols(self: *ExecutorGlobals) *zend.Array {
        return zend.Array.from(&self.ptr().symbol_table);
    }

    /// Return a userland superglobal from `EG(symbol_table)`.
    ///
    /// Unlike `PhpGlobals.httpGlobal`, this accesses the zval slot that PHP
    /// userland reads and writes as `$_GET`, `$_POST`, and so on. The returned
    /// wrapper borrows the owner zval stored in the symbol table without
    /// changing its copy-on-write state.
    pub fn superglobal(self: *ExecutorGlobals, comptime which: Superglobal) ?*Zval.Array {
        which.ensureInitialized();
        const name = which.name();

        const value = self.symbols().find(name) orelse return null;
        return Zval.Array.from(value) catch null;
    }

    /// Return a userland superglobal prepared for mutation.
    ///
    /// This calls `separate()` before returning so PHP's array copy-on-write
    /// rules are applied to the owner zval stored in `EG(symbol_table)`.
    pub fn superglobalMut(self: *ExecutorGlobals, comptime which: Superglobal) ?*Zval.Array {
        const value = self.superglobal(which) orelse return null;
        value.separate();
        return value;
    }

    pub inline fn functions(self: *ExecutorGlobals) *zend.Array {
        return zend.Array.from(self.ptr().function_table);
    }

    pub inline fn classes(self: *ExecutorGlobals) *zend.Array {
        return zend.Array.from(self.ptr().class_table);
    }

    pub inline fn exception(self: *ExecutorGlobals) ?*zend.Object {
        const object = self.ptr().exception orelse return null;
        return zend.Object.from(object);
    }
};

pub const CompilerGlobals = opaque {
    pub inline fn from(globals: *c.zend_compiler_globals) *CompilerGlobals {
        return @ptrCast(globals);
    }

    pub inline fn ptr(self: *CompilerGlobals) *c.zend_compiler_globals {
        return @ptrCast(@alignCast(self));
    }

    // TODO: more impl...
};

pub const SapiGlobals = opaque {
    pub inline fn from(globals: *c.sapi_globals_struct) *SapiGlobals {
        return @ptrCast(globals);
    }

    pub inline fn ptr(self: *SapiGlobals) *c.sapi_globals_struct {
        return @ptrCast(@alignCast(self));
    }

    // TODO: more impl...
};

pub const FileGlobals = opaque {
    pub inline fn from(globals: *c.php_file_globals) *FileGlobals {
        return @ptrCast(globals);
    }

    pub inline fn ptr(self: *FileGlobals) *c.php_file_globals {
        return @ptrCast(@alignCast(self));
    }

    // TODO: more impl...
};

pub const PhpGlobals = opaque {
    pub const HttpSuperglobal = enum(c_int) {
        GET = c.TRACK_VARS_GET,
        POST = c.TRACK_VARS_POST,
        COOKIE = c.TRACK_VARS_COOKIE,
        SERVER = c.TRACK_VARS_SERVER,
        ENV = c.TRACK_VARS_ENV,
        FILES = c.TRACK_VARS_FILES,

        pub fn name(comptime self: HttpSuperglobal) []const u8 {
            return "_" ++ @tagName(self);
        }

        pub inline fn ensureInitialized(comptime self: HttpSuperglobal) void {
            const global_name = self.name();
            _ = c.zend_is_auto_global_str(global_name.ptr, global_name.len);
        }

        pub fn index(comptime self: HttpSuperglobal) usize {
            return @intCast(@backingInt(self));
        }
    };

    pub inline fn from(core_globals: *c.php_core_globals) *PhpGlobals {
        return @ptrCast(core_globals);
    }

    pub inline fn ptr(self: *PhpGlobals) *c.php_core_globals {
        return @ptrCast(@alignCast(self));
    }

    /// Return a PHP request superglobal from `PG(http_globals)`.
    ///
    /// Unlike `ExecutorGlobals.superglobal`, this returns PHP core's request
    /// source zval, not the userland variable slot in `EG(symbol_table)`.
    /// This is not a writable API; no reference is added, and callers must not
    /// mutate, destroy, or retain it across requests or threads. To write to a
    /// userland superglobal, use `ExecutorGlobals.superglobalMut()`.
    pub fn httpGlobal(self: *PhpGlobals, comptime which: HttpSuperglobal) ?*Zval.Array {
        which.ensureInitialized();
        return Zval.Array.from(&self.ptr().http_globals[which.index()]) catch null;
    }
};

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(ExecutorGlobals.Superglobal);
    std.testing.refAllDecls(@This().class);
    std.testing.refAllDecls(ExecutorGlobals);
    std.testing.refAllDecls(CompilerGlobals);
    std.testing.refAllDecls(PhpGlobals);
    std.testing.refAllDecls(PhpGlobals.HttpSuperglobal);
    std.testing.refAllDecls(SapiGlobals);
    std.testing.refAllDecls(FileGlobals);
}
