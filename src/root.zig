const std = @import("std");

pub const c = @import("c.zig").c;

pub const zts = c.USING_ZTS != 0;
pub const debug = c.ZEND_DEBUG != 0;
pub const php_version = c.PHP_VERSION;
pub const php_version_id = c.PHP_VERSION_ID;

pub const globals = @import("globals.zig");
pub const sapi = @import("sapi.zig");
pub const tsrm = @import("tsrm.zig");

pub const closure = @import("closure.zig");

pub const heap = @import("heap.zig");
pub const ini = @import("ini.zig");
pub const info = @import("info.zig");
pub const observer = @import("observer.zig");

const mod_helper = @import("module.zig");
pub const module = mod_helper.module;
pub const initModuleEntry = mod_helper.initModuleEntry;
pub const ModuleEntry = mod_helper.ModuleEntry;
pub const ModuleGlobals = mod_helper.ModuleGlobals;

pub const zend = @import("zend.zig");

const class_helper = @import("class.zig");
pub const Class = class_helper.Class;
pub const ClassDecl = class_helper.ClassDecl;
pub const ObjectHandlers = class_helper.ObjectHandlers;
pub const ClassEntry = zend.ClassEntry;
pub const Operator = class_helper.Operator;
pub const Comparison = class_helper.Comparison;
pub const GcBuffer = @import("gc.zig").GcBuffer;

pub const function = @import("function.zig").function;
pub const functions = @import("function.zig").functions;
pub const namedFunctions = @import("function.zig").namedFunctions;

pub const Ctx = @import("ctx.zig").Ctx;
pub const CallFrame = @import("ctx.zig").CallFrame;
pub const Nullable = CallFrame.Nullable;
pub const Mixed = CallFrame.Mixed;
pub const GuardCtx = @import("ctx.zig").GuardCtx;
pub const Zval = @import("zval.zig").Zval;
pub const Guard = @import("guard.zig").Guard;
pub const GuardScope = @import("guard.zig").Scope;
pub const Stream = @import("stream.zig").Stream;

pub const errors = @import("errors.zig");

pub fn printf(fmt: [:0]const u8, args: anytype) usize {
    return @call(.auto, c.php_printf, .{fmt.ptr} ++ args);
}

/// Execute a script using PHP's script runner. Standalone hosts should use
/// tryExecuteScript to also catch bailouts escaping PHP's internal boundaries.
pub fn executeScript(file: *zend.FileHandle) error{ScriptExecutionFailed}!void {
    if (!c.php_execute_script(file.ptr())) return error.ScriptExecutionFailed;
}

/// Execute a script in the active request with an outer bailout boundary.
/// PHP reports script exceptions and maps internally caught bailouts to
/// ScriptExecutionFailed; any escaping bailout becomes ZendBailout.
/// The caller retains ownership of file and must still shut down the request.
pub fn tryExecuteScript(file: *zend.FileHandle) (error{ScriptExecutionFailed} || zend.bailout.Error)!void {
    return zend.bailout.run(executeScript, .{file});
}

/// Evaluate PHP code in the active request. Exceptions remain pending; bailouts
/// propagate to the caller's boundary. Standalone hosts should use tryEval.
pub fn eval(code: []const u8, retval: ?*Zval, name: [:0]const u8) error{ CodeExecutionFailed, PhpException }!void {
    const result = c.zend_eval_stringl(code.ptr, code.len, if (retval) |value| value.ptr() else null, name.ptr);
    if (errors.hasException()) return error.PhpException;
    if (result != c.SUCCESS) return error.CodeExecutionFailed;
}

/// Like eval, but converts a PHP bailout to error.ZendBailout. Ordinary PHP
/// exceptions still return PhpException and remain pending for the caller.
/// After a bailout, finish request shutdown instead of continuing PHP execution.
/// This boundary does not include subsequent exception reporting or cleanup.
pub fn tryEval(code: []const u8, retval: ?*Zval, name: [:0]const u8) (error{ CodeExecutionFailed, PhpException } || zend.bailout.Error)!void {
    return zend.bailout.run(eval, .{ code, retval, name });
}

test {
    _ = @import("ctx.zig");
    _ = @import("class.zig");
    _ = @import("closure.zig");
    _ = @import("errors.zig");
    _ = @import("function.zig");
    _ = @import("globals.zig");
    _ = @import("gc.zig");
    _ = @import("heap.zig");
    _ = @import("guard.zig");
    _ = @import("ini.zig");
    _ = @import("info.zig");
    _ = @import("module.zig");
    _ = @import("observer.zig");
    _ = @import("sapi.zig");
    _ = @import("tsrm.zig");
    _ = @import("stub.zig");
    _ = @import("stream.zig");
    _ = @import("zend.zig");
    _ = @import("zval.zig");
    _ = @import("zend/array.zig");
    _ = @import("zend/callable.zig");
    _ = @import("zend/class_entry.zig");
    _ = @import("zend/function.zig");
    _ = @import("zend/file_handle.zig");
    _ = @import("zend/object.zig");
    _ = @import("zend/property_info.zig");
    _ = @import("zend/string.zig");
    _ = @import("zend/bailout.zig");
    _ = @import("zval/array.zig");
    _ = @import("zval/object.zig");

    std.testing.refAllDecls(@This());
}
