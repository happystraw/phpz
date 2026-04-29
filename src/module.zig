const std = @import("std");

const phpz_options = @import("phpz_options");

const c = @import("root.zig").c;
pub const ModuleEntry = c.zend_module_entry;
const function_helper = @import("function.zig");

/// Configuration for creating a PHP extension module.
///
/// This structure defines the metadata and lifecycle hooks for a PHP extension.
/// All lifecycle hooks are optional and will be called by PHP at appropriate times.
pub const Config = struct {
    /// Extension name (must be null-terminated).
    /// This should match the filename of your extension (.so file).
    /// Example: "my_extension"
    name: [:0]const u8,

    /// Extension version string (null-terminated).
    /// Displayed in phpinfo() and php -m output.
    /// Default: "0.0.0"
    version: [:0]const u8 = "0.0.0",

    /// Module startup hook, called when PHP starts (e.g., when Apache starts).
    /// Use this to initialize resources that persist across requests.
    /// Called once per PHP process/thread pool initialization.
    startup_fn: ?PhpHookFn = null,

    /// Module shutdown hook, called when PHP shuts down (e.g., when Apache stops).
    /// Use this to clean up resources initialized in startup_fn.
    /// Called once per PHP process/thread pool shutdown.
    shutdown_fn: ?PhpHookFn = null,

    /// Request startup hook, called at the beginning of each PHP request.
    /// Use this to initialize per-request resources.
    /// Called for every HTTP request or CLI script execution.
    request_startup_fn: ?PhpHookFn = null,

    /// Request shutdown hook, called at the end of each PHP request.
    /// Use this to clean up per-request resources.
    /// Called after every HTTP request or CLI script execution.
    request_shutdown_fn: ?PhpHookFn = null,

    /// phpinfo() hook, called when phpinfo() is invoked.
    /// Use this to display custom information about your extension.
    /// Example: configuration settings, compile-time options, credits.
    info_fn: ?PhpInfoFn = null,
};

pub const PhpInfoFn = fn (*ModuleEntry) void;
pub const PhpHookFn = fn () anyerror!void;

/// Creates and exports a PHP extension module.
///
/// This function creates a PHP module entry structure at compile time and exports
/// the required symbols based on the configuration. For shared library mode, it
/// additionally exports the `get_module` function for the PHP loader.
///
/// Parameters:
///   - cfg: Module configuration including name, version, and lifecycle hook functions
pub fn module(comptime cfg: Config) void {
    comptime {
        if (!@hasDecl(c, "zend_module_entry")) {
            @compileError("Missing zend_module_entry declaration. Please '#include \"php.h\"'");
        }

        const S = struct {
            var entry: ModuleEntry = createModuleEntry(cfg);
            fn getModule() callconv(.c) *ModuleEntry {
                return &entry;
            }
        };
        @export(&S.entry, .{ .name = cfg.name ++ "_module_entry" });
        if (phpz_options.shared) {
            @export(&S.getModule, .{ .name = "get_module" });
        }
    }
}

fn makePhpHookFn(comptime hook_fn: PhpHookFn) *const fn (c_int, c_int) callconv(.c) c.zend_result {
    return struct {
        fn @"fn"(_: c_int, _: c_int) callconv(.c) c.zend_result {
            hook_fn() catch |err| {
                c.zend_error(c.E_ERROR, "Module hook function failed: %s", @errorName(err).ptr);
                return c.FAILURE;
            };
            return c.SUCCESS;
        }
    }.@"fn";
}

fn makePhpInfoFn(comptime info_fn: PhpInfoFn) *const fn ([*c]ModuleEntry) callconv(.c) void {
    return struct {
        fn @"fn"(entry: [*c]ModuleEntry) callconv(.c) void {
            info_fn(@ptrCast(entry));
        }
    }.@"fn";
}

inline fn createModuleEntry(comptime cfg: Config) ModuleEntry {
    var entry: ModuleEntry = undefined;

    // STANDARD_MODULE_HEADER
    entry.size = @sizeOf(ModuleEntry);
    entry.zend_api = c.ZEND_MODULE_API_NO;
    entry.zend_debug = c.ZEND_DEBUG;
    entry.zts = c.USING_ZTS;
    entry.ini_entry = null;
    entry.deps = null;

    // EXTENSION SETUP
    entry.name = cfg.name;
    entry.functions = if (@hasDecl(c, "ext_functions")) &c.ext_functions else null;
    entry.module_startup_func = if (cfg.startup_fn) |f| makePhpHookFn(f) else null;
    entry.module_shutdown_func = if (cfg.shutdown_fn) |f| makePhpHookFn(f) else null;
    entry.request_startup_func = if (cfg.request_startup_fn) |f| makePhpHookFn(f) else null;
    entry.request_shutdown_func = if (cfg.request_shutdown_fn) |f| makePhpHookFn(f) else null;
    entry.info_func = if (cfg.info_fn) |f| makePhpInfoFn(f) else null;
    entry.version = cfg.version;

    // STANDARD_MODULE_PROPERTIES
    entry.globals_size = 0;
    entry.globals_ctor = null;
    entry.globals_dtor = null;
    entry.post_deactivate_func = null;
    entry.module_started = 0;
    entry.type = 0;
    entry.handle = null;
    entry.module_number = 0;
    entry.build_id = "API" ++ std.fmt.comptimePrint("{d}", .{c.ZEND_MODULE_API_NO}) ++ c.ZEND_BUILD_TS ++ c.ZEND_BUILD_DEBUG;

    if (@hasField(ModuleEntry, "globals_id_ptr")) {
        // ZTS
        entry.globals_id_ptr = null;
    } else {
        entry.globals_ptr = null;
    }

    return entry;
}

test {
    std.testing.refAllDecls(@This());
}
