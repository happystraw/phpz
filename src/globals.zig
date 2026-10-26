const std = @import("std");
const builtin = @import("builtin");

const abi = @import("abi.zig");
const c = @import("c.zig").c;
const CallFrame = @import("ctx.zig").CallFrame;
const exception_helper = @import("exception.zig");
const SapiGlobals = @import("sapi.zig").Globals;
const tsrm = @import("tsrm.zig");
const zend = @import("zend.zig");
const Zval = @import("zval.zig").Zval;

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

pub inline fn stdObjectHandlers() c.zend_object_handlers {
    return global(.value, c.zend_object_handlers, "std_object_handlers");
}

/// Borrow the active SAPI module definition, shared across threads.
/// This is distinct from the per-thread SAPI globals returned by sapi().
pub inline fn sapiModule() *c.sapi_module_struct {
    return global(.ptr, c.sapi_module_struct, "sapi_module");
}

const zts = c.USING_ZTS != 0;

inline fn fastGlobals(comptime T: type, comptime offset_name: []const u8) *T {
    return tsrm.fastBulk(T, global(.value, usize, offset_name));
}

pub inline fn executor() *ExecutorGlobals {
    if (comptime zts) return .from(fastGlobals(c.zend_executor_globals, "executor_globals_offset"));
    return .from(c.phpz_executor_globals());
}

pub inline fn compiler() *CompilerGlobals {
    if (comptime zts) return .from(fastGlobals(c.zend_compiler_globals, "compiler_globals_offset"));
    return .from(c.phpz_compiler_globals());
}

pub inline fn php() *PhpGlobals {
    if (comptime zts) return .from(fastGlobals(c.php_core_globals, "core_globals_offset"));
    return .from(c.phpz_core_globals());
}

pub inline fn sapi() *SapiGlobals {
    if (comptime zts) return .from(fastGlobals(c.sapi_globals_struct, "sapi_globals_offset"));
    return .from(c.phpz_sapi_globals());
}

pub inline fn file() *FileGlobals {
    if (comptime zts) return .from(tsrm.bulk(c.php_file_globals, global(.value, c_int, "file_globals_id")));
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

    /// Return the current call frame, or null when no execution frame is active.
    /// Ownership: borrowed frame owned by Zend; only valid while the frame exists.
    pub inline fn currentCallFrame(self: *ExecutorGlobals) ?*CallFrame {
        const frame = self.ptr().current_execute_data;
        if (frame == null) return null;
        return CallFrame.from(frame);
    }

    pub fn exitStatus(self: *ExecutorGlobals) exception_helper.ExitStatus {
        return @fromBackingInt(@intCast(self.ptr().exit_status));
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

    /// Borrow the current thread's global constant table after executor initialization.
    /// PHP owns the table and its entries; do not release them.
    pub inline fn constants(self: *ExecutorGlobals) *zend.Array {
        return zend.Array.from(self.ptr().zend_constants);
    }

    pub inline fn exception(self: *ExecutorGlobals) ?*zend.Object {
        const object = self.ptr().exception orelse return null;
        return zend.Object.from(object);
    }

    pub inline fn iniDirectives(self: *ExecutorGlobals) *zend.Array {
        return zend.Array.from(self.ptr().ini_directives);
    }

    /// Borrow PHP's persistent resource registry without changing reference counts.
    /// PHP owns the table and its entries; do not release them.
    pub inline fn persistentList(self: *ExecutorGlobals) *zend.Array {
        return zend.Array.from(&self.ptr().persistent_list);
    }
};

pub const CompilerGlobals = opaque {
    pub inline fn from(globals: *c.zend_compiler_globals) *CompilerGlobals {
        return @ptrCast(globals);
    }

    pub inline fn ptr(self: *CompilerGlobals) *c.zend_compiler_globals {
        return @ptrCast(@alignCast(self));
    }

    /// Borrow the compiler class table, including classes registered during MINIT.
    pub inline fn classes(self: *CompilerGlobals) *zend.Array {
        return .from(self.ptr().class_table);
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
    std.testing.refAllDecls(ExecutorGlobals);
    std.testing.refAllDecls(CompilerGlobals);
    std.testing.refAllDecls(PhpGlobals);
    std.testing.refAllDecls(PhpGlobals.HttpSuperglobal);
    std.testing.refAllDecls(SapiGlobals);
    std.testing.refAllDecls(FileGlobals);
}
