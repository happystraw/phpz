//! PHP function/method call context.
const std = @import("std");
const builtin = @import("builtin");

const c = @import("root.zig").c;
const stub = @import("stub.zig");
const exception = @import("exception.zig");
const argument = @import("argument.zig");
const closure = @import("closure.zig");
const resource_guard = @import("guard.zig");
const GuardScope = resource_guard.Scope;
const Guard = resource_guard.Guard;
const zend = @import("zend.zig");
const ClassEntry = @import("zend/class_entry.zig").ClassEntry;
const Zval = @import("zval.zig").Zval;

const Variadic = argument.Variadic;

/// Provides access to the current call frame and return value.
/// Passed as `Ctx` to user-defined PHP function/method bindings.
///
/// Fields:
///   - `call`: parameter parsing, argument access, scope info
///   - `retval`: set the PHP return value
///
/// Example:
/// ```zig
/// fn add(ctx: Ctx) !void {
///     const args = try ctx.call.expectArgs(&.{
///         .{ .int = .{} },
///         .{ .int = .{} },
///     }, {});
///     ctx.ret(.int, args[0] + args[1]);
/// }
/// ```
pub const Ctx = struct {
    call: *CallFrame,
    retval: *Zval,

    pub inline fn ret(self: Ctx, comptime kind: Zval.Kind, value: Zval.Type(kind)) void {
        self.retval.set(kind, value);
    }
};

/// Use instead of Ctx in a function, method, constructor, or Closure callback
/// to enable a handler-local guard scope. Arbitrary Zig defer is not covered.
/// Do not retain this context beyond the handler or across threads.
pub const GuardCtx = struct {
    call: *CallFrame,
    retval: *Zval,
    guard_scope: *?*GuardScope,

    pub inline fn ret(self: GuardCtx, comptime kind: Zval.Kind, value: Zval.Type(kind)) void {
        self.retval.set(kind, value);
    }

    /// Borrow the call frame and return value without guard access.
    pub fn asCtx(self: GuardCtx) Ctx {
        return .{ .call = self.call, .retval = self.retval };
    }

    /// Register value for cleanup on return, bailout, or request shutdown.
    /// Ownership transfers only on success; release() cleans early, take() returns it.
    /// Propagate ZendBailout so caller errdefer can run.
    /// Cleanup must not call PHP or bailout; stored pointers must outlive cleanup.
    pub fn guard(self: GuardCtx, value: anytype, comptime cleanup: fn (@TypeOf(value)) void) !Guard(@TypeOf(value)) {
        return (try resource_guard.ScopeObject.ensure(self.guard_scope)).register(value, cleanup);
    }
};

/// Parameter parsing and call frame access.
///
/// This is Zend's call frame: it wraps `zend_execute_data`, the structure
/// php-src itself calls a call frame (`ZEND_CALL_FRAME_SLOT`). It provides
/// type-safe argument extraction via `expectArgs` / `expectArg` /
/// `expectArgCount`, or the lower-level ZPP format interface `parseArgs()`.
pub const CallFrame = opaque {
    /// Initialize a CallFrame from PHP execution data.
    ///
    /// This is typically called automatically by the function/method wrapper.
    /// You don't need to call this manually in user code.
    ///
    /// Parameters:
    ///   - execute_data: The PHP execution data pointer
    ///
    /// Returns:
    ///   An initialized CallFrame
    pub inline fn from(execute_data: *c.zend_execute_data) *CallFrame {
        return @ptrCast(execute_data);
    }

    /// Get the underlying zend_execute_data pointer
    pub inline fn ptr(self: *CallFrame) *c.zend_execute_data {
        return @ptrCast(@alignCast(self));
    }

    /// Get the function executed by this call frame.
    ///
    /// Ownership: borrowed function pointer owned by Zend.
    pub inline fn function(self: *CallFrame) ?*zend.Function {
        const fn_ptr = self.ptr().func orelse return null;
        return .from(fn_ptr);
    }

    /// Get the number of argument slots, including resolved named parameters and
    /// defaults filled by Zend. Extra named variadic arguments are not included.
    pub inline fn argCount(self: *CallFrame) u32 {
        return self.ptr().This.u2.num_args;
    }

    /// Unsafe: Get the Nth argument (1-indexed) as a raw zval pointer.
    ///
    /// Parameters:
    ///   - n: Argument number (1-based)
    ///
    /// Returns:
    ///   Pointer to the zval at position n
    pub inline fn arg(self: *CallFrame, n: u32) *c.zval {
        const base: [*]c.zval = @ptrCast(self.ptr());
        return &base[@as(usize, @intCast(c.ZEND_CALL_FRAME_SLOT)) + @as(usize, n) - 1];
    }

    /// Borrow the argument slots, including resolved named parameters.
    /// Extra named variadic arguments are separate: use extraNamedArgs() to read
    /// them, or expectNoExtraNamedArgs() to reject them before processing slots.
    pub fn args(self: *CallFrame) []c.zval {
        const count = self.argCount();
        const base: [*]c.zval = @ptrCast(self.ptr());
        return base[c.ZEND_CALL_FRAME_SLOT..][0..count];
    }

    /// Borrow the extra named variadic arguments of this call, or null if absent.
    /// Check the call flag before reading the potentially uninitialized field.
    /// The call frame owns the table: do not release or structurally modify it.
    /// Copy/addref values explicitly if they must outlive the call.
    pub fn extraNamedArgs(self: *CallFrame) ?*zend.Array {
        if (c.ZEND_CALL_INFO(self.ptr()) & c.ZEND_CALL_HAS_EXTRA_NAMED_PARAMS == 0) return null;
        return .from(self.ptr().extra_named_params);
    }

    /// Reject extra named variadic arguments in the currently executing call.
    /// Names matched to declared parameters are unaffected.
    pub fn expectNoExtraNamedArgs(self: *CallFrame) exception.Error!void {
        if (c.ZEND_CALL_INFO(self.ptr()) & c.ZEND_CALL_HAS_EXTRA_NAMED_PARAMS != 0) {
            return exception.unexpectedExtraNamedArgs();
        }
    }

    /// Validate the number of argument slots against expected min/max.
    /// Does not check extra named variadic arguments.
    /// Call once at the top of each function, before accessing individual args.
    pub fn expectArgCount(self: *CallFrame, min: u32, max: u32) exception.Error!void {
        const count = self.argCount();
        if (count < min or count > max) {
            return exception.wrongParameterCount(min, max);
        }
    }

    /// Expect zero arguments in the currently executing call, including named extras.
    pub fn expectNoArgs(self: *CallFrame) exception.Error!void {
        try self.expectNoExtraNamedArgs();
        if (self.argCount() != 0) {
            return exception.wrongParametersNone();
        }
    }

    pub const ExpectArgsError = exception.Error;
    pub const ExpectArgsRuntime = argument.ExpectArgsRuntime;

    /// Extract and type-check arguments using compile-time specifications.
    /// Rejects extra named arguments unless the last spec is .variadic, which
    /// returns a borrowed Variadic view accepting positional and named extras.
    /// Call Variadic.check() explicitly to restrict the accepted argument sources.
    /// Element types are checked lazily through Variadic.Entry.expect().
    /// Optionals must come after required args. min/max derived automatically.
    ///
    /// Each entry is an `ExpectArgKind.Spec` tagged union literal. The `runtime`
    /// parameter is `ExpectArgsRuntime(specs)` — `{}` when all specs need no
    /// runtime extension, or a tuple of per-position `Runtime` structs.
    ///
    /// Example:
    /// ```zig
    /// // Scalar only — runtime is void, pass {}:
    /// // (string $name, int $age = 0, ?int $count = null)
    /// const args = try self.expectArgs(&.{
    ///     .{ .string = .{} },
    ///     .{ .int = .{ .optional = true } },
    ///     .{ .int = .{ .optional = true, .nullable = true } },
    /// }, {});
    /// const name: []const u8 = args[0];
    /// const age: ?i64 = args[1];
    /// const count: ?phpz.Nullable(i64) = args[2];
    ///
    /// // With callable/object runtime extensions:
    /// // (callable $cb, \User $user)
    /// var cb: zend.Callable = .nil;
    /// const args2 = try self.expectArgs(&.{
    ///     .{ .callable = .{ .resolve = true } },
    ///     .{ .object = .{ .instanceof = true } },
    /// }, .{
    ///     .{ .out = &cb },
    ///     .{ .class = UserClass.entry },
    /// });
    ///
    /// // .mixed with union types:
    /// // (int|string $id_or_name)
    /// const args3 = try self.expectArgs(&.{
    ///     .{ .mixed = .{ .one_of = &.{ .int, .string } } },
    /// }, {});
    /// switch (args3[0]) {
    ///     .int => |id| _ = id,
    ///     .string => |name| _ = name,
    /// }
    ///
    /// // Check a reference and its value, while keeping the reference writable:
    /// const args4 = try self.expectArgs(&.{
    ///     .{ .reference = .{ .kind = .int, .as = .value } },
    /// }, {});
    /// const value: *Zval = args4[0];
    ///
    /// // Collect the tail, accepting positional and extra named arguments:
    /// const args5 = try self.expectArgs(&.{
    ///     .{ .string = .{} },
    ///     .{ .variadic = .{} },
    /// }, {});
    /// var it = args5[1].iterator();
    /// while (it.next()) |entry| {
    ///     const value = try entry.expect(.{ .int = .{} }, {});
    ///     _ = value;
    /// }
    /// ```
    pub fn expectArgs(
        self: *CallFrame,
        comptime specs: []const ExpectArgKind.Spec,
        runtime: ExpectArgsRuntime(specs),
    ) exception.Error!argument.ExpectArgResults(specs) {
        @setEvalBranchQuota(comptime stub.declarationQuota(specs.len));
        const min = comptime min: {
            var count: u32 = 0;
            var seen_optional = false;
            for (specs, 0..) |spec, i| {
                if (spec == .variadic) {
                    if (i != specs.len - 1) @compileError(".variadic must be the last argument specification");
                    continue;
                }
                if (seen_optional and !spec.isOptional()) {
                    @compileError(std.fmt.comptimePrint(
                        "argument {d} (.{s}) is required but follows an optional; all required arguments must come first",
                        .{ i + 1, @tagName(spec) },
                    ));
                }
                if (spec.isOptional())
                    seen_optional = true
                else
                    count += 1;
            }
            break :min count;
        };

        const has_variadic = comptime specs.len != 0 and specs[specs.len - 1] == .variadic;

        if (comptime builtin.mode == .debug) self.assertArgsDeclaration(min, @intCast(specs.len - @intFromBool(has_variadic)), has_variadic);
        if (comptime !has_variadic) try self.expectNoExtraNamedArgs();

        const max: u32 = if (comptime has_variadic) std.math.maxInt(u32) else @intCast(specs.len);

        try self.expectArgCount(min, max);
        const rest = if (comptime has_variadic) Variadic.init(self.args(), self.extraNamedArgs(), @intCast(specs.len - 1)) else {};

        const Results = argument.ExpectArgResults(specs);
        var result: Results = undefined;
        inline for (specs, 0..) |spec, i| {
            if (comptime spec == .variadic) {
                result[i] = rest;
                continue;
            }
            const arg_runtime = if (comptime @TypeOf(runtime) != void)
                @field(runtime, std.fmt.comptimePrint("{d}", .{i}))
            else {};
            const n: u32 = @intCast(i + 1);
            result[i] = if (comptime spec.isOptional())
                if (n > self.argCount()) null else try argument.extractValue(.{ .position = n }, self.arg(n), spec, arg_runtime)
            else
                try argument.extractValue(.{ .position = n }, self.arg(n), spec, arg_runtime);
        }
        return result;
    }

    fn assertArgsDeclaration(self: *CallFrame, required: u32, fixed: u32, variadic: bool) void {
        const func = self.function() orelse return;
        if (closure.isPhpzClosure(func)) return;
        if (func.requiredParamCount() == required and
            func.fixedParamCount() == fixed and func.isVariadic() == variadic) return;

        const class_scope = func.scope();
        std.debug.panic(
            "{s}{s}{s}(): expectArgs declaration mismatch: specs require {d}, fixed {d}, variadic {}; declaration requires {d}, fixed {d}, variadic {}",
            .{
                if (class_scope) |class| class.name() else "",
                if (class_scope != null) "::" else "",
                func.name(),
                required,
                fixed,
                variadic,
                func.requiredParamCount(),
                func.fixedParamCount(),
                func.isVariadic(),
            },
        );
    }

    pub const ExpectArgKind = argument.ExpectArgKind;

    /// Extract and type-check argument N (1-indexed). Must call expectArgCount first.
    ///
    /// Accepts an `ExpectArgKind.Spec` tagged union specifying the expected type
    /// and options (optional, nullable, as). Pass runtime extension data via `runtime`:
    ///   - `.callable` with `.resolve = true`    → `.{ .out = &cb }`
    ///   - `.callable` without resolve           → `{}`
    ///   - `.object` with `.instanceof = true`   → `.{ .class = entry }` (class/interface)
    ///   - `.object` without instanceof          → `{}`
    ///   - all other specs → `{}`
    ///
    /// `.as = .zval` returns a borrowed `*Zval`; use `.ptr()` for the C pointer.
    /// With `nullable`, PHP null is a Zval; with `optional`, an omitted argument is Zig null.
    /// `.mixed` without unions and `.callable` also return borrowed `*Zval` values.
    /// Nullable callables return `phpz.Nullable(*Zval)`; optional arguments wrap the result in `?`.
    /// For `.reference`, `as` selects a borrowed view:
    /// `.reference` (default) returns `*zend.Reference`, `.zval` returns the outer
    /// container as `*Zval`, and `.value` returns the referenced value as `*Zval`.
    /// `.kind` only checks the referenced value; it does not change the result type.
    /// Numeric `.as` selects the Zig width (e.g. `.u8`, `.f32`); out-of-range
    /// values raise a parameter ValueError. Strings default to `.string`, with
    /// `.cstr` borrowing a NUL-terminated `[:0]const u8` and `.str` borrowing a
    /// `*zend.String`, without allocation or addref. Keep the source string alive
    /// and unchanged while using these views. `.cstr` preserves embedded NULs;
    /// passing its `.ptr` to a C string API stops at the first NUL.
    /// `.resource.as = .stream` borrows a `*Stream` from an ordinary or persistent
    /// stream resource; keep it alive and open. Invalid streams raise PHP TypeError.
    /// `nullable` wraps it in `phpz.Nullable(*Stream)`; `optional` adds an outer `?`.
    /// A resolved callable writes `runtime.out` only for a present non-null
    /// value. Initialize it before use; later argument failures do not roll it back.
    ///
    /// Prefer `expectArgs` for multi-arg cases.
    pub fn expectArg(
        self: *CallFrame,
        arg_num: u32,
        comptime spec: ExpectArgKind.Spec,
        runtime: ExpectArgKind.Runtime(spec),
    ) exception.Error!argument.ExpectArgResult(spec) {
        if (comptime spec == .variadic) @compileError(".variadic is only valid as the last expectArgs specification");
        if (arg_num > self.argCount()) {
            if (comptime spec.isOptional())
                return null
            else {
                return exception.argumentValueError(arg_num, "must be provided", .{});
            }
        }
        return argument.extractValue(.{ .position = arg_num }, self.arg(arg_num), spec, runtime);
    }

    pub const ParseArgsError = error{ParseFailure};

    /// Parse function parameters according to a type specification.
    ///
    /// This function wraps PHP's zend_parse_parameters() to extract typed arguments
    /// from the PHP function call. It validates types and converts PHP values to
    /// the expected Zig types.
    ///
    /// Type Specification Format:
    ///   The type_spec string uses single characters to indicate expected types:
    ///
    ///   Scalar Types:
    ///     - 'l'  (long)         -> i64 (1 arg: &val)
    ///     - 'd'  (double)       -> f64 (1 arg: &val)
    ///     - 'b'  (bool)         -> bool (1 arg: &val)
    ///
    ///   String Types:
    ///     - 's'  (string)       -> [*]u8 + size_t (2 args: &ptr, &len)
    ///     - 'S'  (zend_string)  -> *c.zend_string (1 arg: &ptr)
    ///     - 'p'  (path)         -> [*]u8 + size_t, rejects strings containing null bytes (2 args: &ptr, &len)
    ///     - 'P'  (path zstring) -> *c.zend_string, rejects strings containing null bytes (1 arg: &ptr)
    ///
    ///   Array / Hashtable:
    ///     - 'a'  (array)        -> *c.zval (1 arg: &ptr)
    ///     - 'A'  (array, deref) -> *c.zval (1 arg: &ptr; like 'a', already dereferenced)
    ///     - 'h'  (hashtable)    -> *c.HashTable (1 arg: &ptr)
    ///     - 'H'  (hashtable, deref) -> *c.HashTable (1 arg: &ptr; like 'h', already dereferenced)
    ///
    ///   Object / Class:
    ///     - 'o'  (object)       -> *c.zval (1 arg: &ptr)
    ///     - 'O'  (typed object) -> *c.zval + *c.zend_class_entry (2 args: &ptr, class_entry)
    ///     - 'C'  (class entry)  -> *c.zend_class_entry (1 arg: &ptr)
    ///
    ///   Callable:
    ///     - 'f'  (callable)     -> *c.zend_fcall_info + *c.zend_fcall_info_cache (2 args: &fci, &fcc)
    ///
    ///   Resource:
    ///     - 'r'  (resource)     -> *c.zval (1 arg: &ptr)
    ///
    ///   Mixed / Any:
    ///     - 'z'  (zval)         -> *c.zval, any type (1 arg: &ptr)
    ///     - 'n'  (zval, nullable) -> *c.zval, any type, allows null (1 arg: &ptr) (PHP 8.1+)
    ///
    ///   Modifiers:
    ///     - '!'  (nullable)     : Permits null for the preceding specifier
    ///     - '/'  (separate)     : Calls SEPARATE_ZVAL on the preceding specifier (copy-on-write safety)
    ///
    ///   Separators:
    ///     - '|'  (optional)     : All specifiers after this are optional
    ///     - '*'  (variadic 0+)  : Variable number of arguments (0 or more) -> *c.zval + *u32 (2 args: &arr, &count)
    ///     - '+'  (variadic 1+)  : Variable number of arguments (1 or more) -> *c.zval + *u32 (2 args: &arr, &count)
    ///
    ///   Quick Reference:
    ///     - "ll"      : Two required integers
    ///     - "s"       : One required string (needs &ptr, &len)
    ///     - "sl"      : One string and one integer
    ///     - "l|s"     : One required integer, one optional string
    ///     - "z!"      : One nullable zval
    ///     - "s|l"     : One required string, one optional integer
    ///     - "s/"      : One string (will be separated for CoW safety)
    ///     - "z*"      : Any zval + variadic zvals + count (3 args: &ptr, &arr, &count)
    ///
    /// Parameters:
    ///   - type_spec: Type specification string (null-terminated)
    ///   - args: Tuple of pointers to receive the parsed values
    ///
    /// Returns:
    ///   Error.ParseFailure if parsing fails (wrong type, missing required param)
    ///
    /// Example:
    /// ```zig
    /// // --- Scalar types ---
    ///
    /// // 'l': function(int $n)
    /// var n: i64 = undefined;
    /// try ctx.call.parseArgs("l", .{&n});
    ///
    /// // 'd': function(float $x)
    /// var x: f64 = undefined;
    /// try ctx.call.parseArgs("d", .{&x});
    ///
    /// // 'b': function(bool $flag)
    /// var flag: bool = undefined;
    /// try ctx.call.parseArgs("b", .{&flag});
    ///
    /// // --- String types ---
    ///
    /// // 's': function(string $msg)  -- requires 2 args: &ptr, &len
    /// var msg: []u8 = undefined;
    /// try ctx.call.parseArgs("s", .{ &msg.ptr, &msg.len });
    ///
    /// // 'S': function(string $msg)  -- receives zend_string* directly (1 arg)
    /// var zs: *c.zend_string = undefined;
    /// try ctx.call.parseArgs("S", .{&zs});
    /// const s = zend.String.from(zs).slice();
    ///
    /// // 'p': function(string $path)  -- like 's' but rejects null bytes
    /// var path: []u8 = undefined;
    /// try ctx.call.parseArgs("p", .{ &path.ptr, &path.len });
    ///
    /// // 'P': function(string $path)  -- like 'S' but rejects null bytes
    /// var zp: *c.zend_string = undefined;
    /// try ctx.call.parseArgs("P", .{&zp});
    ///
    /// // --- Raw zval (any type) ---
    ///
    /// // 'z': function(mixed $val)
    /// var raw: *c.zval = undefined;
    /// try ctx.call.parseArgs("z", .{&raw});
    /// const val = Zval.from(raw);
    /// if (val.is(.int)) {
    ///     const num = val.asUnchecked(.int);
    ///     _ = num;
    /// }
    ///
    /// // 'n': function(mixed $val = null)  -- allows null (PHP 8.1+)
    /// var nraw: *c.zval = undefined;
    /// try ctx.call.parseArgs("n", .{&nraw});
    ///
    /// // --- Array and Hashtable ---
    ///
    /// // 'a': function(array $arr)
    /// var arr_zv: *c.zval = undefined;
    /// try ctx.call.parseArgs("a", .{&arr_zv});
    /// const arr = arr_zv.value.arr; // extract zend_array*
    ///
    /// // 'A': function(array $arr)  -- like 'a', already dereferenced
    /// var arr_zv2: *c.zval = undefined;
    /// try ctx.call.parseArgs("A", .{&arr_zv2});
    ///
    /// // 'h': function(array $map)  -- receives HashTable* directly
    /// var ht: *c.HashTable = undefined;
    /// try ctx.call.parseArgs("h", .{&ht});
    ///
    /// // 'H': function(array $map)  -- like 'h', already dereferenced
    /// var ht2: *c.HashTable = undefined;
    /// try ctx.call.parseArgs("H", .{&ht2});
    ///
    /// // --- Object / Class ---
    ///
    /// // 'o': function(object $obj)  -- any object
    /// var obj: *c.zval = undefined;
    /// try ctx.call.parseArgs("o", .{&obj});
    ///
    /// // 'O': function(MyClass $obj)  -- specific class, requires 2 args: &ptr, class_entry
    /// var typed_obj: *c.zval = undefined;
    /// try ctx.call.parseArgs("O", .{ &typed_obj, my_class_entry });
    ///
    /// // 'C': function(string $class)  -- receives zend_class_entry* directly
    /// var ce: *c.zend_class_entry = undefined;
    /// try ctx.call.parseArgs("C", .{&ce});
    ///
    /// // --- Callable ---
    ///
    /// // 'f': function(callable $cb)  -- requires 2 args
    /// var fci: c.zend_fcall_info = undefined;
    /// var fcc: c.zend_fcall_info_cache = undefined;
    /// try ctx.call.parseArgs("f", .{ &fci, &fcc });
    ///
    /// // --- Resource ---
    ///
    /// // 'r': function(resource $handle)
    /// var res: *c.zval = undefined;
    /// try ctx.call.parseArgs("r", .{&res});
    ///
    /// // --- Mixed types ---
    ///
    /// // 'sl': function(string $name, int $count)
    /// var name: []u8 = undefined;
    /// var count: i64 = undefined;
    /// try ctx.call.parseArgs("sl", .{ &name.ptr, &name.len, &count });
    ///
    /// // --- Optional and nullable ---
    ///
    /// // 's|l': function(string $key, int $ttl = 0)  -- caller sets default
    /// var key: []u8 = undefined;
    /// var ttl: i64 = 0;
    /// try ctx.call.parseArgs("s|l", .{ &key.ptr, &key.len, &ttl });
    ///
    /// // 's|z!': function(string $name, ?int $age = null)
    /// var person_name: []u8 = undefined;
    /// var age_opt: ?*c.zval = null;
    /// try ctx.call.parseArgs("s|z!", .{ &person_name.ptr, &person_name.len, &age_opt });
    /// // With z!, both omitted and PHP null leave a null pointer.
    /// if (age_opt) |age_zval| {
    ///     if (Zval.raw.is(age_zval, .int)) {
    ///         const age = Zval.raw.asUnchecked(age_zval, .int);
    ///         _ = age;
    ///     }
    /// }
    ///
    /// // --- SEPARATE_ZVAL (CoW safety) ---
    ///
    /// // 's/': function(string $msg)  -- string will be separated
    /// var cow_msg: []u8 = undefined;
    /// try ctx.call.parseArgs("s/", .{ &cow_msg.ptr, &cow_msg.len });
    ///
    /// // --- Variadic ---
    ///
    /// // 'z*': function(mixed ...$args)  -- 0 or more variadic arguments
    /// var first: *c.zval = undefined;
    /// var rest: [*]c.zval = undefined;
    /// var rest_count: u32 = undefined;
    /// try ctx.call.parseArgs("z*", .{ &first, &rest, &rest_count });
    ///
    /// // '+': function(mixed $first, mixed ...$args)  -- 1 or more variadic arguments
    /// var fst: [*]c.zval = undefined;
    /// var rst_count: u32 = undefined;
    /// try ctx.call.parseArgs("+", .{ &fst, &rst_count });
    /// ```
    /// Parses the currently executing call. Extra named variadic arguments are
    /// rejected because this interface cannot return their names and values.
    pub fn parseArgs(self: *CallFrame, comptime type_spec: [:0]const u8, type_args: anytype) ParseArgsError!void {
        if (@typeInfo(@TypeOf(type_args)) != .@"struct") {
            @compileError("parseArgs: args must be a tuple (use .{} syntax)");
        }
        self.expectNoExtraNamedArgs() catch return ParseArgsError.ParseFailure;
        const result = @call(
            .auto,
            c.zend_parse_parameters,
            .{ self.argCount(), type_spec.ptr } ++ type_args,
        );
        if (result == c.FAILURE) return ParseArgsError.ParseFailure;
    }

    /// Get the current frame's $this object value.
    ///
    /// Returns the current object context when called from a method.
    /// Returns null when called from a static method or function.
    ///
    /// Returns:
    ///   The $this object value, or null if not in an object context
    pub fn thisValue(self: *CallFrame) ?*Zval.Object {
        return Zval.Object.from(&self.ptr().This) catch null;
    }

    /// Get the current frame's $this object.
    ///
    /// Returns null when called from a static method or function.
    ///
    /// Returns:
    ///   The Object pointer, or null if not in an object context
    pub fn this(self: *CallFrame) ?*zend.Object {
        const value = self.thisValue() orelse return null;
        return value.zendObject();
    }

    /// Resolve the $this object using Zend's call-frame lookup rules.
    ///
    /// Unlike `this`, this may walk through unscoped internal-function frames
    /// and return an object from an eligible caller frame.
    pub fn getThisObject(self: *CallFrame) ?*zend.Object {
        const obj = c.zend_get_this_object(self.ptr());
        return if (obj) |o| .from(o) else null;
    }

    /// Get the class where the current function was defined.
    ///
    /// This reads the current function's declaration scope directly and does
    /// not search previous call frames. Returns null for a global function.
    ///
    /// Returns:
    ///   The class entry, or null if not in a class context
    pub fn scope(self: *CallFrame) ?*ClassEntry {
        const func = self.function() orelse return null;
        return func.scope();
    }

    /// Resolve the called scope using Zend's call-frame lookup rules.
    ///
    /// For an instance method, this is the runtime class of `$this`. For a
    /// static method, this is the class stored as the call's late-static-binding
    /// scope. Unlike `scope`, this may walk through unscoped internal-function
    /// frames and return the called scope from an eligible caller frame.
    ///
    /// In an inheritance context, this returns the class used to invoke the
    /// method, which may be a child class, while `scope` returns the class where
    /// the method was defined.
    ///
    /// Example:
    ///   class Parent { function foo() { ... } }
    ///   class Child extends Parent {}
    ///   $obj = new Child();
    ///   $obj->foo(); // scope() = Parent, calledScope() = Child
    ///
    /// Returns:
    ///   The called class entry, or null when no called scope can be resolved
    pub fn calledScope(self: *CallFrame) ?*ClassEntry {
        const raw = c.zend_get_called_scope(self.ptr());
        return if (raw) |ce| .from(ce) else null;
    }
};

test {
    std.testing.refAllDecls(Ctx);
    std.testing.refAllDecls(GuardCtx);
    std.testing.refAllDecls(CallFrame);
}
