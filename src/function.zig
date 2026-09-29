const std = @import("std");

const abi = @import("abi.zig");
const c = @import("root.zig").c;
const Ctx = @import("ctx.zig").Ctx;
const GuardCtx = @import("ctx.zig").GuardCtx;
const CallFrame = @import("ctx.zig").CallFrame;
const errors = @import("errors.zig");
const guard = @import("guard.zig");
const stub = @import("stub.zig");
const zend = @import("zend.zig");
const Zval = @import("zval.zig").Zval;
const Stream = @import("stream.zig").Stream;

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
/// The optional Ctx or GuardCtx must be first. Other parameters are extracted
/// through CallFrame.expectArgs. Non-void results are written to PHP's result zval;
/// void/!void leaves it unchanged, allowing the function to set it manually.
/// Use a context-only signature for expectArgs specifications that a Zig type
/// cannot express.
/// A `*Stream` parameter borrows a PHP stream; keep its resource alive and open.
/// `?T` permits omission; `CallFrame.Nullable(T)` permits PHP null.
///
/// When the function takes neither a context nor PHP parameters, extra arguments
/// are rejected. A context-only handler retains control of its own parsing.
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
/// fn twice(value: u8) i64 {
///     return @as(i64, value) * 2;
/// }
///
/// fn add(ctx: Ctx) !void {
///     const args = try ctx.call.expectArgs(&.{
///         .{ .int = .{} },
///         .{ .int = .{} },
///     }, {});
///     ctx.retval.set(.int, args[0] + args[1]);
/// }
///
/// fn greet(ctx: Ctx) !void {
///     const args = try ctx.call.expectArgs(&.{
///         .{ .string = .{} },
///     }, {});
///     var buffer: [256]u8 = undefined;
///     const greeting = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{args[0]});
///     ctx.retval.set(.string, greeting);
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

fn NullablePayloadType(comptime T: type) ?type {
    if (@typeInfo(T) != .@"union" or !@hasField(T, "value")) return null;
    const Payload = @FieldType(T, "value");
    return if (T == CallFrame.Nullable(Payload)) Payload else null;
}

fn mixedKinds(comptime T: type) ?[]const CallFrame.ExpectArgKind {
    comptime {
        if (@typeInfo(T) != .@"union") return null;
        const info = @typeInfo(T).@"union";
        if (info.tag_type == null or info.field_names.len < 2) return null;
        var kinds: [info.field_names.len]CallFrame.ExpectArgKind = undefined;
        for (info.field_names, 0..) |name, i| {
            if (!@hasField(CallFrame.ExpectArgKind, name)) return null;
            const kind = @field(CallFrame.ExpectArgKind, name);
            if (kind == .mixed or kind == .reference or kind == .callable) return null;
            kinds[i] = kind;
        }
        const result = kinds;
        return if (T == CallFrame.Mixed(&result)) &result else null;
    }
}

fn specFor(comptime T: type) CallFrame.ExpectArgKind.Spec {
    const optional = @typeInfo(T) == .optional;
    const Inner = if (optional) @typeInfo(T).optional.child else T;
    const nullable = NullablePayloadType(Inner) != null;
    const Base = NullablePayloadType(Inner) orelse Inner;
    const Spec = CallFrame.ExpectArgKind.Spec;

    inline for (.{ i8, i16, i32, i64, isize, u8, u16, u32, u64, usize }) |Int| {
        if (Base == Int) {
            const As = @TypeOf((@as(Spec, .{ .int = .{} })).int.as);
            return .{ .int = .{ .as = @field(As, @typeName(Int)), .optional = optional, .nullable = nullable } };
        }
    }
    if (Base == f32 or Base == f64) {
        return .{ .float = .{ .as = if (Base == f32) .f32 else .f64, .optional = optional, .nullable = nullable } };
    }
    if (Base == []const u8) return .{ .string = .{ .as = .string, .optional = optional, .nullable = nullable } };
    if (Base == *zend.String) return .{ .string = .{ .as = .str, .optional = optional, .nullable = nullable } };
    if (Base == bool) return .{ .bool = .{ .optional = optional, .nullable = nullable } };
    if (Base == *zend.Array) return .{ .array = .{ .optional = optional, .nullable = nullable } };
    if (Base == *zend.Object) return .{ .object = .{ .optional = optional, .nullable = nullable } };
    if (Base == *zend.Resource) return .{ .resource = .{ .optional = optional, .nullable = nullable } };
    if (Base == *Stream) return .{ .resource = .{ .as = .stream, .optional = optional, .nullable = nullable } };
    if (Base == *zend.Reference and !nullable) return .{ .reference = .{ .optional = optional } };
    if (Base == *Zval and !nullable) return .{ .mixed = .{ .optional = optional } };
    if (Base == *zend.Callable) return .{ .callable = .{ .optional = optional, .nullable = nullable, .resolve = true } };
    if (!nullable) if (mixedKinds(Base)) |kinds| return .{ .mixed = .{ .optional = optional, .one_of = kinds } };
    @compileError("unsupported PHP handler parameter type " ++ @typeName(T) ++ "; use a leading Ctx or GuardCtx and call expectArgs for complex specifications");
}

fn makeCallableArg(comptime T: type, parsed: anytype, resolved: *zend.Callable) T {
    if (@typeInfo(T) == .optional) {
        return if (parsed) |present| makeCallableArg(@typeInfo(T).optional.child, present, resolved) else null;
    }
    if (NullablePayloadType(T) != null) {
        return switch (parsed) {
            .null => .null,
            .value => .{ .value = resolved },
        };
    }
    return resolved;
}

pub fn ContextType(comptime func: anytype, comptime has_receiver: bool) type {
    const params = @typeInfo(@TypeOf(func)).@"fn".param_types;
    const index: usize = if (has_receiver) 1 else 0;
    if (params.len > index and (params[index] == Ctx or params[index] == GuardCtx)) return params[index].?;
    return Ctx;
}

fn ResultType(comptime func: anytype) type {
    const R = @typeInfo(@TypeOf(func)).@"fn".return_type.?;
    return if (@typeInfo(R) == .error_union) @typeInfo(R).error_union.payload else R;
}

pub fn invoke(comptime func: anytype, ctx: anytype, receiver: anytype) anyerror!ResultType(func) {
    const param_types = @typeInfo(@TypeOf(func)).@"fn".param_types;
    const has_receiver = @TypeOf(receiver) != void;
    const context_idx: usize = if (has_receiver) 1 else 0;
    const has_context = param_types.len > context_idx and (param_types[context_idx] == Ctx or param_types[context_idx] == GuardCtx);
    const php_params_offset = context_idx + @intFromBool(has_context);
    const php_params_count = param_types.len - php_params_offset;
    comptime {
        if (has_context and param_types[context_idx] != @TypeOf(ctx)) {
            @compileError("handler context type does not match its binding");
        }
        for (param_types[php_params_offset..]) |ParamType| {
            if (ParamType == Ctx or ParamType == GuardCtx) @compileError("Ctx or GuardCtx must precede all PHP parameters");
        }
    }

    var params: std.meta.ArgsTuple(@TypeOf(func)) = undefined;
    if (comptime has_receiver) params[0] = receiver;
    if (comptime has_context) params[context_idx] = ctx;
    comptime var callable_count = 0;
    const specs = comptime blk: {
        var arg_specs: [php_params_count]CallFrame.ExpectArgKind.Spec = undefined;
        for (0..php_params_count) |i| {
            arg_specs[i] = specFor(param_types[php_params_offset + i].?);
            if (arg_specs[i] == .callable) callable_count += 1;
        }
        break :blk arg_specs;
    };
    var resolved_callables: [callable_count]zend.Callable = @splat(.nil);
    if (comptime php_params_count == 0) {
        if (comptime !has_context) try ctx.call.expectNoArgs();
    } else {
        var runtime: CallFrame.ExpectArgsRuntime(&specs) = undefined;
        if (comptime @TypeOf(runtime) != void) {
            comptime var callable_idx = 0;
            inline for (specs, 0..) |spec, i| {
                if (comptime spec == .callable) {
                    runtime[i] = .{ .out = &resolved_callables[callable_idx] };
                    callable_idx += 1;
                } else runtime[i] = {};
            }
        } else runtime = {};
        const values = try ctx.call.expectArgs(&specs, runtime);
        inline for (specs, 0..) |spec, i| {
            const ParamType = param_types[php_params_offset + i].?;
            params[php_params_offset + i] = if (comptime spec == .callable)
                makeCallableArg(ParamType, values[i], runtime[i].out)
            else
                values[i];
        }
    }
    return @call(.auto, func, params);
}

pub fn setReturnValue(retval: *Zval, value: anytype) anyerror!void {
    const T = @TypeOf(value);
    if (T == void) return;
    if (@typeInfo(T) == .optional) {
        if (value) |present| return setReturnValue(retval, present);
        retval.set(.null, {});
        return;
    }
    if (comptime mixedKinds(T) != null) {
        switch (value) {
            inline else => |payload| if (@TypeOf(payload) == void)
                retval.set(.null, {})
            else
                try setReturnValue(retval, payload),
        }
        return;
    }
    if (NullablePayloadType(T) != null) {
        switch (value) {
            .null => retval.set(.null, {}),
            .value => |present| try setReturnValue(retval, present),
        }
        return;
    }
    if (T == bool) return retval.set(.bool, value);
    inline for (.{ i8, i16, i32, i64, isize, u8, u16, u32, u64, usize }) |Int| {
        if (T == Int) {
            const number = std.math.cast(c.zend_long, value) orelse return error.ReturnValueOutOfRange;
            return retval.set(.int, @intCast(number));
        }
    }
    if (T == f32 or T == f64) return retval.set(.float, @floatCast(value));
    if (T == []u8 or T == []const u8) return retval.set(.string, value);
    if (T == *zend.String) return retval.set(.str, value);
    if (T == *zend.Array) return retval.set(.array, value);
    if (T == *zend.Object) return retval.set(.object, value);
    if (T == *zend.Resource) return retval.set(.resource, value);
    if (T == *zend.Reference) return retval.set(.reference, value);
    if (T == *Zval) return retval.set(.mixed, value.ptr());
    @compileError("unsupported PHP handler return type " ++ @typeName(T));
}

pub fn createHandler(comptime func_desc: [:0]const u8, comptime func: anytype) Handler {
    const Context = ContextType(func, false);
    return struct {
        fn call(ctx: Context) anyerror!void {
            const value = try invoke(func, ctx, {});
            try setReturnValue(ctx.retval, value);
        }

        fn handle(execute_data: ?*c.zend_execute_data, return_value: ?*c.zval) callconv(abi.fn_cc) void {
            @as(
                anyerror!void,
                if (comptime Context == GuardCtx) blk: {
                    var scope: ?*guard.Scope = null;
                    defer if (scope) |owned| guard.ScopeObject.release(owned);
                    break :blk zend.bailout.run(call, .{GuardCtx{
                        .call = .from(execute_data.?),
                        .retval = .from(return_value.?),
                        .guard_scope = &scope,
                    }});
                } else call(.{ .call = .from(execute_data.?), .retval = .from(return_value.?) }),
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
