//! PHP function/method call context.
const std = @import("std");

const c = @import("root.zig").c;
const errors = @import("errors.zig");
const zend = @import("zend.zig");
const ClassEntry = @import("zend/class_entry.zig").ClassEntry;
const Zval = @import("zval.zig").Zval;
const native = Zval.native;

/// Provides access to the current call frame and return value.
/// Passed as `Ctx` to user-defined PHP function/method bindings.
///
/// Fields:
///   - `call`: parameter parsing, argument access, scope info
///   - `ret`: set the PHP return value
///
/// Example:
/// ```zig
/// fn add(ctx: Ctx) !void {
///     var a: i64 = undefined;
///     var b: i64 = undefined;
///     try ctx.call.parseArgs("ll", .{ &a, &b });
///     ctx.ret.set(.int, a + b);
/// }
/// ```
const Ctx = @This();

call: *Call,
ret: *Zval,

/// Parameter parsing and call frame access.
///
/// Wraps `zend_execute_data` to provide type-safe argument extraction
/// via `expectArgs` / `expectArg` / `expectArgCount`, or the lower-level
/// `parseArgs()` for complex type specs (callable, object, variadic, etc.).
pub const Call = opaque {
    /// Initialize a Call from PHP execution data.
    ///
    /// This is typically called automatically by the function/method wrapper.
    /// You don't need to call this manually in user code.
    ///
    /// Parameters:
    ///   - execute_data: The PHP execution data pointer
    ///
    /// Returns:
    ///   An initialized Call
    pub inline fn from(execute_data: *c.zend_execute_data) *Call {
        return @ptrCast(execute_data);
    }

    /// Get the underlying zend_execute_data pointer
    pub inline fn ptr(self: *Call) *c.zend_execute_data {
        return @ptrCast(@alignCast(self));
    }

    /// Get the number of arguments passed to the current function/method.
    ///
    /// Returns:
    ///   The argument count
    pub inline fn argCount(self: *Call) u32 {
        return self.ptr().This.u2.num_args;
    }

    /// Unsafe: Get the Nth argument (1-indexed) as a raw zval pointer.
    ///
    /// Parameters:
    ///   - n: Argument number (1-based)
    ///
    /// Returns:
    ///   Pointer to the zval at position n
    pub inline fn arg(self: *Call, n: u32) *c.zval {
        const base: [*]c.zval = @ptrCast(self.ptr());
        return &base[c.ZEND_CALL_FRAME_SLOT + n - 1];
    }

    /// Get all arguments as a slice of zvals.
    pub inline fn args(self: *Call) []c.zval {
        const count = self.argCount();
        const base: [*]c.zval = @ptrCast(self.ptr());
        return base[c.ZEND_CALL_FRAME_SLOT..][0..count];
    }

    /// Validate the total number of arguments against expected min/max.
    /// Call once at the top of each function, before accessing individual args.
    pub inline fn expectArgCount(self: *Call, min: u32, max: u32) errors.WrongParameterCountError!void {
        const count = self.argCount();
        if (count < min or count > max) {
            return errors.wrongParameterCount(min, max);
        }
    }

    /// Expect zero arguments. Calls zend_wrong_parameters_none_error on failure.
    pub inline fn expectNoArgs(self: *Call) errors.WrongParameterCountError!void {
        if (self.argCount() != 0) {
            return errors.wrongParametersNone();
        }
    }

    /// Error set for `expectArgs`: argument count mismatch, missing required argument, or type mismatch.
    pub const ExpectArgsError = ExpectArgError || errors.WrongParameterCountError;

    fn ExpectArgResults(comptime specs: []const ExpectArgKind.Spec) type {
        comptime {
            var types: [specs.len]type = undefined;
            for (specs, 0..) |spec, i| {
                types[i] = ExpectArgResult(spec);
            }
            return @Tuple(&types);
        }
    }

    fn ExpectArgsRuntime(comptime specs: []const ExpectArgKind.Spec) type {
        comptime {
            var types: [specs.len]type = undefined;
            var is_all_void = true;
            for (specs, 0..) |spec, i| {
                types[i] = ExpectArgKind.Runtime(spec);
                if (is_all_void and types[i] != void) is_all_void = false;
            }
            return if (is_all_void) void else @Tuple(&types);
        }
    }

    /// Extract all arguments with compile-time validation.
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
    /// const count: ?Nullable(i64) = args[2];
    ///
    /// // With callable/object runtime extensions:
    /// // (callable $cb, \User $user)
    /// var cb: zend.Callable = .nil;
    /// const args2 = try self.expectArgs(&.{
    ///     .{ .callable = .{ .resolve = true } },
    ///     .{ .object = .{ .instanceof = true } },
    /// }, .{
    ///     .{ .target = &cb },
    ///     .{ .type = UserClass.entry },
    /// });
    ///
    /// // .mixed with union types:
    /// // (int|string $id_or_name)
    /// const args3 = try self.expectArgs(&.{
    ///     .{ .mixed = .{ .unions = &.{ .int, .string } } },
    /// }, {});
    /// switch (args3[0]) {
    ///     .int => |id| _ = id,
    ///     .string => |name| _ = name,
    /// }
    /// ```
    pub inline fn expectArgs(
        self: *Call,
        comptime specs: []const ExpectArgKind.Spec,
        runtime: ExpectArgsRuntime(specs),
    ) ExpectArgsError!ExpectArgResults(specs) {
        comptime {
            var seen_optional = false;
            for (specs, 0..) |spec, i| {
                if (seen_optional and !spec.isOptional()) {
                    @compileError(std.fmt.comptimePrint(
                        "argument {d} (.{s}) is required but follows an optional; all required arguments must come first",
                        .{ i + 1, @tagName(spec) },
                    ));
                }
                if (spec.isOptional()) seen_optional = true;
            }
        }

        const min = comptime min: {
            var count: u32 = 0;
            for (specs) |spec| {
                if (!spec.isOptional()) count += 1;
            }
            break :min count;
        };
        const max: u32 = @intCast(specs.len);

        try self.expectArgCount(min, max);

        const Results = ExpectArgResults(specs);
        var result: Results = undefined;
        inline for (specs, 0..) |spec, i| {
            const arg_runtime = if (comptime @TypeOf(runtime) != void)
                @field(runtime, std.fmt.comptimePrint("{d}", .{i}))
            else {};
            const n: u32 = @intCast(i + 1);
            result[i] = if (comptime spec.isOptional())
                if (n > self.argCount()) null else try self.extractArg(n, spec, arg_runtime)
            else
                try self.extractArg(n, spec, arg_runtime);
        }
        return result;
    }

    pub const ExpectArgError = errors.ArgumentTypeError || errors.ArgumentValueError;

    /// Argument parsing type tags, aligned with ZPP (fast zend_parse_parameters).
    ///
    /// Each member maps to a ZPP type spec and macro:
    ///
    ///   ExpectArgKind    ZPP spec    ZPP macro
    ///   ─────────────    ────────    ─────────
    ///   .null            -           -
    ///   .int             'l'         Z_PARAM_LONG
    ///   .float           'd'         Z_PARAM_DOUBLE
    ///   .string          's'/'S'     Z_PARAM_STR
    ///   .bool            'b'         Z_PARAM_BOOL
    ///   .array           'a'/'h'     Z_PARAM_ARRAY / Z_PARAM_ARRAY_HT
    ///   .object          'o'         Z_PARAM_OBJECT
    ///   .resource        'r'         Z_PARAM_RESOURCE
    ///   .reference       -           (internal zval type, no ZPP macro)
    ///   .mixed           'z'         Z_PARAM_ZVAL
    ///   .callable        'f'         Z_PARAM_FUNC
    ///
    /// `.null` exists for use in `.mixed` unions; it cannot be used as a standalone argument type.
    pub const ExpectArgKind = enum {
        null,
        int,
        float,
        string,
        bool,
        array,
        object,
        resource,
        reference,
        mixed,

        /// callable is a special case: it doesn't have a direct zval type,
        /// but is parsed via Z_PARAM_FUNC and requires both fci and fcc.
        callable,

        fn BuildSpec(ak: ExpectArgKind) type {
            return switch (ak) {
                .null => unreachable,
                .mixed => struct { optional: bool = false, unions: ?[]const ExpectArgKind = null },
                .object => struct { optional: bool = false, nullable: bool = false, zval: bool = false, instanceof: bool = false },
                .callable => struct { optional: bool = false, nullable: bool = false, resolve: bool = false },
                .reference => struct { optional: bool = false, zval: bool = false },
                else => struct { optional: bool = false, nullable: bool = false, zval: bool = false },
            };
        }

        pub const Spec = union(ExpectArgKind) {
            null,
            int: BuildSpec(.int),
            float: BuildSpec(.float),
            string: BuildSpec(.string),
            bool: BuildSpec(.bool),
            array: BuildSpec(.array),
            object: BuildSpec(.object),
            resource: BuildSpec(.resource),
            reference: BuildSpec(.reference),
            mixed: BuildSpec(.mixed),
            callable: BuildSpec(.callable),

            pub fn isOptional(self: Spec) bool {
                return switch (self) {
                    .null => false,
                    inline else => |m| m.optional,
                };
            }
        };

        /// Runtime extension data for a single `Spec`.
        ///   - `.callable` with `.resolve = true`    → `struct { target: *zend.Callable }`
        ///   - `.callable` without resolve           → `void`
        ///   - `.object` with `.instanceof = true`   → `struct { type: *zend.ClassEntry }` (class/interface)
        ///   - `.object` without instanceof          → `void`
        ///   - scalar types                          → `void` (pass `{}`)
        pub fn Runtime(comptime spec: Spec) type {
            return switch (spec) {
                .callable => |s| if (s.resolve) struct { target: *zend.Callable } else void,
                .object => |s| if (s.instanceof) struct { type: *zend.ClassEntry } else void,
                else => void,
            };
        }

        inline fn toZvalKind(self: ExpectArgKind) Zval.Kind {
            return switch (self) {
                .reference, .mixed, .callable => unreachable,
                inline else => |k| @field(Zval.Kind, @tagName(k)),
            };
        }

        inline fn InnerType(self: ExpectArgKind) type {
            return Zval.Type(self.toZvalKind());
        }
    };

    fn ExpectArgResult(comptime spec: ExpectArgKind.Spec) type {
        return switch (spec) {
            .null => @compileError(".null cannot be used as a standalone type; use another type with the `nullable` flag or use .mixed with unions to allow null as a distinct case"),
            .mixed => |s| {
                if (s.unions) |u| {
                    if (u.len <= 1) @compileError("invalid .mixed specification: unions array must contain at least 2 types");
                    const TagInt = @typeInfo(ExpectArgKind).@"enum".tag_type;
                    var field_names: [u.len][]const u8 = undefined;
                    var field_types: [u.len]type = undefined;
                    var field_attrs: [u.len]std.lang.Type.Union.FieldAttributes = undefined;
                    var field_values: [u.len]TagInt = undefined;
                    inline for (u, 0..) |kind, i| {
                        if (kind == .mixed) @compileError("invalid .mixed specification: unions cannot contain .mixed");
                        if (kind == .reference) @compileError("invalid .mixed specification: unions cannot contain .reference");
                        if (kind == .callable) @compileError("invalid .mixed specification: unions cannot contain .callable");
                        for (u[0..i]) |prev| if (prev == kind) @compileError("invalid .mixed specification: unions contains duplicate type ." ++ @tagName(kind));
                        field_names[i] = @tagName(kind);
                        field_types[i] = kind.InnerType();
                        field_attrs[i] = .{};
                        field_values[i] = @intFromEnum(kind);
                    }

                    const PhpUnionType = @Union(
                        .auto,
                        @Enum(TagInt, .exhaustive, &field_names, &field_values),
                        &field_names,
                        &field_types,
                        &field_attrs,
                    );
                    return if (s.optional) ?PhpUnionType else PhpUnionType;
                } else {
                    return if (s.optional) ?*c.zval else *c.zval;
                }
            },
            .callable => |s| {
                const T = if (s.nullable) Nullable(*c.zval) else *c.zval;
                return if (s.optional) ?T else T;
            },
            .reference => |s| {
                const T = if (s.zval) *c.zval else *zend.Reference;
                return if (s.optional) ?T else T;
            },
            inline else => |s| {
                const tag: ExpectArgKind = spec;
                const T = if (s.zval)
                    *c.zval
                else if (s.nullable)
                    Nullable(tag.InnerType())
                else
                    tag.InnerType();
                return if (s.optional) ?T else T;
            },
        };
    }

    /// Returned when `nullable` is set: distinguishes "null was passed" (.null) from "argument omitted" (?T).
    pub fn Nullable(comptime T: type) type {
        return union(enum) {
            null,
            value: T,

            pub fn asOptional(self: @This()) ?T {
                return switch (self) {
                    .null => null,
                    .value => |v| v,
                };
            }
        };
    }

    /// Extract and type-check argument N (1-indexed). Must call expectArgCount first.
    ///
    /// Accepts an `ExpectArgKind.Spec` tagged union specifying the expected type
    /// and options (optional, nullable, zval). Pass runtime extension data via `runtime`:
    ///   - `.callable` with `.resolve = true`    → `.{ .target = &cb }`
    ///   - `.callable` without resolve           → `{}`
    ///   - `.object` with `.instanceof = true`   → `.{ .type = entry }` (class/interface)
    ///   - `.object` without instanceof          → `{}`
    ///   - scalar types → `{}`
    ///
    /// Prefer `expectArgs` for multi-arg cases.
    pub inline fn expectArg(
        self: *Call,
        n: u32,
        comptime spec: ExpectArgKind.Spec,
        runtime: ExpectArgKind.Runtime(spec),
    ) ExpectArgError!ExpectArgResult(spec) {
        if (n > self.argCount()) {
            if (comptime spec.isOptional())
                return null
            else {
                return errors.argumentValueError(n, "must be provided", .{});
            }
        }
        return self.extractArg(n, spec, runtime);
    }

    inline fn extractArg(
        self: *Call,
        n: u32,
        comptime spec: ExpectArgKind.Spec,
        runtime: ExpectArgKind.Runtime(spec),
    ) ExpectArgError!ExpectArgResult(spec) {
        const zv = self.arg(n);
        switch (comptime spec) {
            .null => @compileError(".null cannot be used as a standalone type; use another type with the `nullable` flag or use .mixed with unions to allow null as a distinct case"),
            .mixed => |s| {
                if (comptime s.unions) |unions| {
                    const Result = ExpectArgResult(spec);
                    const Union = if (comptime s.optional) @typeInfo(Result).optional.child else Result;
                    comptime var php_union_type: []const u8 = "";
                    inline for (unions) |kind| {
                        if (php_union_type.len > 0) php_union_type = php_union_type ++ "|";
                        php_union_type = php_union_type ++ @tagName(kind);
                        const zk = comptime kind.toZvalKind();
                        if (native.is(zv, zk)) {
                            return @unionInit(Union, @tagName(kind), if (zk == .null) {} else native.asUnchecked(zv, zk));
                        }
                    }
                    return errors.argumentTypeError(n, "must be of type " ++ php_union_type ++ ", %s given", .{native.kind(zv).cstr()});
                } else {
                    return zv;
                }
            },
            .callable => |s| {
                const or_null = comptime if (s.nullable) " or null" else "";
                if (comptime s.nullable) if (native.is(zv, .null)) return .null;
                if (comptime s.resolve) {
                    var err: ?[*:0]u8 = null;
                    runtime.target.parse(zv, false, &err) catch {
                        if (err) |e| {
                            defer if (comptime c.ZEND_DEBUG == 1) c._efree(@as(*anyopaque, @ptrCast(e)), @src().file.ptr, @intCast(@src().line), null, 0) else c.efree(@as(*anyopaque, @ptrCast(e)));
                            return errors.argumentTypeError(n, "must be a valid callback" ++ or_null ++ ", %s", .{e});
                        }
                        return errors.argumentTypeError(n, "must be a valid callback" ++ or_null, .{});
                    };
                } else if (!zend.Callable.isCallable(zv, false)) {
                    return errors.argumentTypeError(n, "must be a valid callback" ++ or_null, .{});
                }
                return if (comptime s.nullable) .{ .value = zv } else zv;
            },
            .reference => |s| {
                return if (native.is(zv, .reference))
                    if (comptime s.zval) zv else native.asUnchecked(zv, .reference)
                else
                    errors.argumentTypeError(n, "must be of type reference, %s given", .{native.kind(zv).cstr()});
            },
            .object => |s| {
                const or_null = comptime if (s.nullable) " or null" else "";
                if (comptime s.nullable) if (native.is(zv, .null)) return .null;
                if (comptime s.instanceof) {
                    const expected_type = runtime.type;
                    const obj: *zend.Object = native.as(zv, .object) catch return errors.argumentTypeError(n, "must be instance of %s" ++ or_null ++ ", %s given", .{ expected_type.name().ptr, native.kind(zv).cstr() });
                    if (!obj.instanceof(expected_type)) return errors.argumentTypeError(n, "must be instance of %s" ++ or_null ++ ", %s given", .{ expected_type.name().ptr, obj.class().name().ptr });
                    const raw = if (comptime s.zval) zv else obj;
                    return if (comptime s.nullable) .{ .value = raw } else raw;
                } else if (!native.is(zv, .object)) {
                    return errors.argumentTypeError(n, "must be of type object" ++ or_null ++ ", %s given", .{native.kind(zv).cstr()});
                }
                const raw = if (comptime s.zval) zv else native.asUnchecked(zv, .object);
                return if (comptime s.nullable) .{ .value = raw } else raw;
            },
            inline else => |s| {
                const tag: ExpectArgKind = spec;
                const or_null = comptime if (s.nullable) " or null" else "";
                if (comptime s.nullable) if (native.is(zv, .null)) return .null;
                const zk = comptime tag.toZvalKind();
                if (!native.is(zv, zk))
                    return errors.argumentTypeError(n, "must be of type " ++ @tagName(tag) ++ or_null ++ ", %s given", .{native.kind(zv).cstr()});
                const raw = if (comptime s.zval) zv else native.asUnchecked(zv, zk);
                return if (comptime s.nullable) .{ .value = raw } else raw;
            },
        }
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
    /// const s = zs.val()[0..zs.len];
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
    /// var age_opt: Zval.Optional = .init;
    /// try ctx.call.parseArgs("s|z!", .{ &person_name.ptr, &person_name.len, &age_opt.ptr });
    /// if (age_opt.unwrap()) |age_zval| {
    ///     if (age_zval.is(.int)) {
    ///         const age = age_zval.asUnchecked(.int);
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
    pub fn parseArgs(self: *Call, comptime type_spec: [:0]const u8, type_args: anytype) ParseArgsError!void {
        if (@typeInfo(@TypeOf(type_args)) != .@"struct") {
            @compileError("parseArgs: args must be a tuple (use .{} syntax)");
        }
        const result = @call(
            .auto,
            c.zend_parse_parameters,
            .{ self.argCount(), type_spec.ptr } ++ type_args,
        );
        if (result == c.FAILURE) return ParseArgsError.ParseFailure;
    }

    /// Get the $this object as a zval (for class methods).
    ///
    /// Returns the current object context when called from a method.
    /// Returns null when called from a static method or function.
    ///
    /// Returns:
    ///   The $this Zval, or null if not in an object context
    pub fn this(self: *Call) ?*Zval {
        const zv = Zval.from(&self.ptr().This);
        return if (zv.is(.object)) zv else null;
    }

    /// Get the $this object as a zend.Object (for class methods).
    ///
    /// This is the preferred way to access the object instance in methods,
    /// as it gives you direct access to the object structure.
    ///
    /// Returns:
    ///   The Object pointer, or null if not in an object context
    pub fn thisObject(self: *Call) ?*zend.Object {
        const obj = c.zend_get_this_object(self.ptr());
        return if (obj) |o| .from(o) else null;
    }

    /// Get the scope (class) where the current function was defined.
    ///
    /// Returns the class entry of the class that defines the current method.
    /// Returns null for non-method contexts.
    ///
    /// Returns:
    ///   The class entry, or null if not in a class context
    pub fn scope(self: *Call) ?*ClassEntry {
        const raw = @as(?*c.zend_class_entry, @ptrCast(self.ptr().func.*.common.scope));
        return if (raw) |ce| ClassEntry.from(ce) else null;
    }

    /// Get the called scope (class) for the current method call.
    ///
    /// In the context of inheritance, this returns the class that was used
    /// to invoke the method (may be a child class), while scope() returns
    /// the class where the method is defined.
    ///
    /// Example:
    ///   class Parent { function foo() { ... } }
    ///   class Child extends Parent {}
    ///   $obj = new Child();
    ///   $obj->foo(); // scope() = Parent, calledScope() = Child
    ///
    /// Returns:
    ///   The class entry of the called class
    pub fn calledScope(self: *Call) ?*ClassEntry {
        const raw = c.zend_get_called_scope(self.ptr());
        return if (raw) |ce| .from(ce) else null;
    }
};

test {
    @import("std").testing.refAllDecls(Ctx);
    @import("std").testing.refAllDecls(Call);
}
