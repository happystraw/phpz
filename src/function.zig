const std = @import("std");

const abi = @import("abi.zig");
const c = @import("root.zig").c;
const Ctx = @import("ctx.zig").Ctx;
const GuardCtx = @import("ctx.zig").GuardCtx;
const errors = @import("errors.zig");
const guard = @import("guard.zig");
const stub = @import("stub.zig");
const zend = @import("zend.zig");

pub const Handler = fn (?*c.zend_execute_data, ?*c.zval) callconv(abi.fn_cc) void;

const FunctionMap = std.StaticStringMap(void);
const required_functions = blk: {
    @setEvalBranchQuota(10_000);
    if (!@hasDecl(c, "ext_functions")) break :blk FunctionMap.initComptime(.{});

    const table = c.ext_functions;
    const Pair = struct { []const u8, void };
    var pairs: [table.len]Pair = undefined;
    var len: usize = 0;

    for (table) |raw| {
        const entry = zend.FunctionEntry.from(&raw);
        const name = entry.name() orelse continue;
        const handler_symbol = stub.functionSymbolName(name);
        if (!@hasDecl(c, handler_symbol)) continue;
        pairs[len] = .{ name, {} };
        len += 1;
    }

    break :blk FunctionMap.initComptime(pairs[0..len]);
};

/// Export the complete set of concrete PHP functions from the generated stub table.
///
/// `bindings` must be a named struct whose fields exactly and case-sensitively
/// match every function that requires a Zig handler. Call this once per
/// extension when all bindings can be declared together. Explicit stub aliases
/// do not require bindings.
///
/// ```zig
/// comptime {
///     phpz.namedFunctions(.{
///         .hello = hello,
///         .@"Vendor\\greet" = greet,
///     });
/// }
/// ```
pub fn namedFunctions(comptime bindings: anytype) void {
    comptime {
        const info = @typeInfo(@TypeOf(bindings));
        if (info != .@"struct" or (info.@"struct".is_tuple and info.@"struct".field_names.len != 0)) {
            @compileError("namedFunctions bindings must be a named struct literal such as .{ .hello = hello }");
        }

        var bound: [required_functions.keys().len]bool = @splat(false);
        var message: []const u8 = "namedFunctions bindings do not match the generated C 'ext_functions' table:";
        var mismatch = false;

        for (info.@"struct".field_names) |func_name| {
            const index = required_functions.getIndex(func_name) orelse {
                mismatch = true;
                message = message ++ "\n  not declared as a concrete stub function: " ++ func_name;
                continue;
            };
            bound[index] = true;
        }

        for (required_functions.keys(), bound) |func_name, is_bound| {
            if (!is_bound) {
                mismatch = true;
                message = message ++ "\n  missing Zig binding: " ++ func_name;
            }
        }
        if (mismatch) @compileError(message);

        for (info.@"struct".field_names) |func_name| {
            function(func_name, @field(bindings, func_name));
        }
    }
}

/// Export the complete set of concrete PHP functions from public Zig declarations.
///
/// Every public function declared by `T` is exported using its declaration name,
/// optionally prefixed by `options.namespace`. Names are matched exactly and
/// case-sensitively against the generated C `ext_functions` table. Public
/// declarations that are not functions are ignored.
///
/// Like `namedFunctions`, this verifies that every concrete stub function has a Zig
/// binding and rejects public Zig functions that are absent from the stub.
///
/// ```zig
/// const Api = struct {
///     pub fn hello() void {}
///     pub fn greet(ctx: phpz.Ctx) !void { _ = ctx; }
/// };
///
/// comptime {
///     phpz.functions(Api, .{ .namespace = "Vendor" });
/// }
/// ```
pub fn functions(comptime T: type, comptime options: struct { namespace: []const u8 = "" }) void {
    comptime {
        if (@typeInfo(T) != .@"struct") {
            @compileError("functions expects a struct or imported Zig file namespace");
        }

        var bound: [required_functions.keys().len]bool = @splat(false);
        var message: []const u8 = "functions for Zig type '" ++ @typeName(T) ++ "' does not match the generated C 'ext_functions' table:";
        var mismatch = false;

        for (std.meta.declarations(T)) |func_name| {
            const func = @field(T, func_name);
            if (@typeInfo(@TypeOf(func)) != .@"fn") continue;

            const php_name = if (options.namespace.len == 0)
                func_name
            else
                options.namespace ++ "\\" ++ func_name;
            const index = required_functions.getIndex(php_name) orelse {
                mismatch = true;
                message = message ++ "\n  not declared as a concrete stub function: " ++ php_name;
                continue;
            };
            bound[index] = true;
        }

        for (required_functions.keys(), bound) |func_name, is_bound| {
            if (!is_bound) {
                mismatch = true;
                message = message ++ "\n  missing Zig binding: " ++ func_name;
            }
        }
        if (mismatch) @compileError(message);

        for (std.meta.declarations(T)) |func_name| {
            const func = @field(T, func_name);
            if (@typeInfo(@TypeOf(func)) != .@"fn") continue;

            const php_name = if (options.namespace.len == 0)
                func_name
            else
                options.namespace ++ "\\" ++ func_name;
            function(php_name, func);
        }
    }
}

/// Export a Zig function as a PHP handler.
///
/// This function creates a PHP function binding at compile time, allowing Zig code
/// to be called from PHP. The function signature is automatically analyzed and
/// adapted to match PHP's calling convention. The function name must identify a
/// concrete handler in the generated C `ext_functions` table.
/// Unlike `functions`, this only validates and exports the named function; it
/// does not report other stub functions that are missing Zig bindings. Prefer
/// `functions` when all extension functions can be bound together.
///
/// Supported function signatures:
///   - `fn (Ctx) void|!void`  - Access parameters and set return value via ctx
///   - `fn (GuardCtx) void|!void` - Also enable native resource cleanup on bailout
///   - `fn () void|!void`     - No parameters or return value
///
/// When the function takes no parameters, PHP will reject calls with extra arguments.
///
/// Parameters:
///   - func_name: The name of the PHP function (null-terminated string)
///   - func: The Zig function to bind
///
/// Example:
/// ```zig
/// fn helloWorld() void {
///     _ = phpz.printf("Hello from ZIG!\n", .{});
/// }
///
/// fn add(ctx: Ctx) !void {
///     const args = try ctx.call.expectArgs(&.{
///         .{ .int = .{} },
///         .{ .int = .{} },
///     }, {});
///     ctx.ret.set(.int, args[0] + args[1]);
/// }
///
/// fn greet(ctx: Ctx) !void {
///     const args = try ctx.call.expectArgs(&.{
///         .{ .string = .{} },
///     }, {});
///     var buffer: [256]u8 = undefined;
///     const greeting = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{args[0]});
///     ctx.ret.set(.string, greeting);
/// }
///
/// // For bindings distributed across multiple Zig modules:
/// comptime {
///     phpz.function("hello_world", helloWorld);
/// }
/// ```
pub fn function(comptime func_name: [:0]const u8, comptime func: anytype) void {
    comptime {
        if (!required_functions.has(func_name)) {
            @compileError("PHP function '" ++ func_name ++ "' was not declared as a concrete function in the generated C 'ext_functions' table");
        }

        const symbol = stub.functionSymbolName(func_name);
        const handler = createHandler(func_name ++ "()", func);
        @export(&handler, .{ .name = symbol });
    }
}

/// Export a Zig function as a PHP class method handler without a backing receiver.
///
/// Similar to `function`, but exports with `zim_` prefix instead of `zif_`.
/// This is the low-level adapter selected by `phpz.Class` for all methods on
/// standard-layout classes and for static methods on backed classes.
pub fn method(comptime class_name: [:0]const u8, comptime func_name: [:0]const u8, comptime func: anytype) void {
    comptime {
        const handler = createHandler(class_name ++ "::" ++ func_name ++ "()", func);
        @export(&handler, .{ .name = stub.methodSymbolName(class_name, func_name) });
    }
}

/// Create a PHP handler from fn(), fn(Ctx), or fn(GuardCtx), returning void or !void.
/// GuardCtx enables bailout capture and resource cleanup.
pub fn createHandler(comptime func_desc: [:0]const u8, comptime invoke: anytype) Handler {
    const params = @typeInfo(@TypeOf(invoke)).@"fn".param_types;
    if (params.len > 1 or (params.len == 1 and params[0] != Ctx and params[0] != GuardCtx)) {
        @compileError("unsupported handler signature for " ++ func_desc ++ ": expected fn(), fn(Ctx), or fn(GuardCtx)");
    }
    const Context = if (params.len == 1) params[0].? else Ctx;
    return struct {
        fn handle(execute_data: ?*c.zend_execute_data, return_value: ?*c.zval) callconv(abi.fn_cc) void {
            @as(
                anyerror!void,
                if (comptime Context == GuardCtx) blk: {
                    var scope = guard.Scope.init(std.heap.c_allocator);
                    defer scope.deinit();
                    break :blk zend.bailout.run(invoke, GuardCtx{
                        .call = .from(execute_data.?),
                        .ret = .from(return_value.?),
                        .guard_scope = &scope,
                    }) catch |err| err;
                } else if (comptime params.len == 0) blk: {
                    const ctx: Ctx = .{ .call = .from(execute_data.?), .ret = .from(return_value.?) };
                    ctx.call.expectNoArgs() catch |err| break :blk err;
                    break :blk invoke();
                } else invoke(.{ .call = .from(execute_data.?), .ret = .from(return_value.?) }),
            ) catch |err| {
                if (err == error.ZendBailout or err == error.OutOfMemory) zend.bailout.raise();
                if (!errors.hasException()) {
                    errors.throwError(null, "%s at " ++ func_desc, .{@errorName(err).ptr}) catch {};
                }
            };
        }
    }.handle;
}

test {
    std.testing.refAllDecls(@This());
}
