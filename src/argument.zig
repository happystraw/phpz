//! Argument specifications, borrowed variadic values, and shared value parsing.
const std = @import("std");

const c = @import("c.zig").c;
const exception = @import("exception.zig");
const globals = @import("globals.zig");
const Stream = @import("stream.zig").Stream;
const stub = @import("stub.zig");
const zend = @import("zend.zig");
const ClassEntry = @import("zend/class_entry.zig").ClassEntry;
const Zval = @import("zval.zig").Zval;

/// Borrowed variadic arguments. Only valid during the current handler call.
/// Do not release or structurally modify the named table while using this view.
/// Copy/addref values explicitly to retain them beyond the call.
/// In typed handlers this must be the last parameter and accepts positional
/// and named arguments; call check() before processing values to restrict them.
pub const Variadic = struct {
    /// Which arguments may appear after the fixed parameters.
    pub const Mode = enum { positional_only, named_only, both };

    positional: []c.zval,
    named: ?*zend.Array,
    /// 1-based position of the first variadic argument in the original call.
    start_position: u32,

    /// Collect a borrowed tail after fixed_count fixed parameters.
    pub fn init(slots: []c.zval, named: ?*zend.Array, fixed_count: u32) Variadic {
        return .{
            .positional = slots[@min(fixed_count, slots.len)..],
            .named = named,
            .start_position = fixed_count + 1,
        };
    }

    /// Return the total number of positional and extra named arguments in the tail.
    pub fn len(self: Variadic) usize {
        return self.positional.len + (if (self.named) |named| named.len() else 0);
    }

    /// Reject disallowed arguments, rather than silently skipping them.
    /// Names matched to fixed parameters are unaffected. Empty tails are valid.
    pub fn check(self: Variadic, mode: Mode) exception.Error!void {
        switch (mode) {
            .both => {},
            .positional_only => if (self.named) |named| {
                if (named.len() != 0) return exception.unexpectedExtraNamedArgs();
            },
            .named_only => if (self.positional.len != 0) {
                const function_name = zend.Function.activeName();
                defer function_name.release();
                return exception.argumentCountError("%s(): Argument #%u cannot be passed positionally; variadic arguments must be named", .{ function_name.cstr(), self.start_position });
            },
        }
    }

    pub const Entry = struct {
        /// Argument position or borrowed name.
        identifier: Identifier,
        /// Borrowed raw value, preserving reference containers.
        value: *Zval,

        /// Return the borrowed name for a named extra, or null for a positional argument.
        pub fn name(self: Entry) ?[:0]const u8 {
            return switch (self.identifier) {
                .name => |value| value,
                .position => null,
            };
        }

        /// Parse this element using the same specs and runtime data as expectArg().
        /// Parsing is lazy: unvisited entries are not checked. Coercions update the
        /// source slot. optional and variadic specs are not valid for an element.
        /// Callable output storage is supplied and owned by the caller.
        pub fn expect(self: Entry, comptime spec: ExpectArgKind.Spec, runtime: ExpectArgKind.Runtime(spec)) exception.Error!ExpectArgResult(spec) {
            comptime {
                if (spec == .variadic) @compileError(".variadic cannot be used to parse one element");
                if (spec.isOptional()) @compileError("variadic elements cannot be optional; next() returns null at the end");
            }
            return extractValue(self.identifier, self.value.ptr(), spec, runtime);
        }
    };

    /// Visit remaining positional arguments, then named arguments in table order.
    pub fn iterator(self: Variadic) Iterator {
        return .{
            .positional = self.positional,
            .named = if (self.named) |named| named.iterator() else null,
            .start_position = self.start_position,
        };
    }

    pub const Iterator = struct {
        positional: []c.zval,
        named: ?zend.Array.Iterator,
        start_position: u32,
        index: usize = 0,

        pub fn next(self: *Iterator) ?Entry {
            if (self.index < self.positional.len) {
                const index = self.index;
                self.index += 1;
                return .{ .identifier = .{ .position = self.start_position + @as(u32, @intCast(index)) }, .value = .from(&self.positional[index]) };
            }
            if (self.named) |*named| {
                if (named.next()) |entry| {
                    return .{ .identifier = .{ .name = entry.key.string }, .value = .from(entry.value) };
                }
            }
            return null;
        }
    };
};

/// Identifies a single argument by position or name and reports diagnostics.
/// Zend's numeric argument diagnostics cannot identify extra named arguments.
pub const Identifier = union(enum) {
    /// 1-based argument position.
    position: u32,
    /// Borrowed argument name, valid while the source argument remains alive.
    name: [:0]const u8,

    /// Report a TypeError for this argument in the currently executing call.
    /// Uses C printf formatting. Preserves a pending exception and returns its error marker.
    pub fn typeError(self: Identifier, comptime format: [:0]const u8, args: anytype) exception.Error {
        return switch (self) {
            .position => |position| exception.argumentTypeError(position, format, args),
            .name => |name| namedError(name, .internal("zend_ce_type_error"), format, args),
        };
    }

    /// Report a ValueError for this argument in the currently executing call.
    /// Uses C printf formatting. Preserves a pending exception and returns its error marker.
    pub fn valueError(self: Identifier, comptime format: [:0]const u8, args: anytype) exception.Error {
        return switch (self) {
            .position => |position| exception.argumentValueError(position, format, args),
            .name => |name| namedError(name, .internal("zend_ce_value_error"), format, args),
        };
    }

    fn namedError(name: [:0]const u8, ce: *ClassEntry, comptime format: [:0]const u8, args: anytype) exception.Error {
        @branchHint(.cold);
        if (exception.pending()) |err| return err;
        const function_name = zend.Function.activeName();
        defer function_name.release();
        return exception.throwError(ce, "%s(): Argument ($%s) " ++ format, .{ function_name.cstr(), name.ptr } ++ args);
    }

    fn expectedTypeError(self: Identifier, expected: c.zend_expected_type, zv: *c.zval) exception.Error {
        @branchHint(.cold);
        return switch (self) {
            .position => |position| exception.wrongParameterType(position, expected, zv),
            .name => self.typeError("must be %s, %s given", .{ c.phpz_expected_type_description(expected), Zval.raw.getValueName(zv) }),
        };
    }

    fn classError(self: Identifier, class: *zend.ClassEntry, comptime nullable: bool, zv: *c.zval) exception.Error {
        @branchHint(.cold);
        switch (self) {
            .position => |position| {
                if (nullable)
                    c.zend_wrong_parameter_class_or_null_error(position, class.name().ptr, zv)
                else
                    c.zend_wrong_parameter_class_error(position, class.name().ptr, zv);
            },
            .name => return self.typeError("must be of type " ++ (if (nullable) "?" else "") ++ "%s, %s given", .{ class.name().ptr, Zval.raw.getValueName(zv) }),
        }
        return exception.pending() orelse error.PhpException;
    }

    fn kindError(self: Identifier, comptime expected: []const u8, zv: *c.zval) exception.Error {
        @branchHint(.cold);
        return self.typeError("must be of type " ++ expected ++ ", %s given", .{Zval.raw.kind(zv).cstr()});
    }
};

pub fn ExpectArgResults(comptime specs: []const ExpectArgKind.Spec) type {
    comptime {
        @setEvalBranchQuota(stub.declarationQuota(specs.len));
        var types: [specs.len]type = undefined;
        for (specs, 0..) |spec, i| {
            types[i] = ExpectArgResult(spec);
        }
        return @Tuple(&types);
    }
}

/// Runtime argument type for expectArgs: void when no spec needs runtime data,
/// otherwise a tuple with one Runtime(spec) entry per argument, including void entries.
pub fn ExpectArgsRuntime(comptime specs: []const ExpectArgKind.Spec) type {
    comptime {
        @setEvalBranchQuota(stub.declarationQuota(specs.len));
        var types: [specs.len]type = undefined;
        var is_all_void = true;
        for (specs, 0..) |spec, i| {
            types[i] = ExpectArgKind.Runtime(spec);
            if (is_all_void and types[i] != void) is_all_void = false;
        }
        return if (is_all_void) void else @Tuple(&types);
    }
}

/// Argument parsing type tags, matching ZPP semantics.
///
/// `.int`, `.float`, `.string` and `.bool` accept their exact type on the fast
/// path and otherwise use Zend's own ZPP coercion: weak mode converts scalars
/// (and Stringable objects for strings) exactly like Z_PARAM_*, `strict_types`
/// rejects them, and int is always accepted for float. Null for a non-nullable
/// scalar follows the PHP version's deprecation rules. A coerced value
/// replaces the argument slot, as it does for PHP userland parameters.
/// `.array`, `.object`, `.resource`, `.reference` and `.mixed` specs do not coerce values.
/// Positional type failures use Zend's argument diagnostics; named failures
/// include the supplied name. Union and reference checks format their own type descriptions.
///
/// Related ZPP specs and macros for value types:
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
/// `.null` can be used in `.mixed` unions or `.reference.kind`, but not as a standalone argument type.
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

    /// Validate callability; resolve = true also populates the caller's Callable.
    callable,

    /// Tail collection marker, not a PHP value type. Valid only at the end of expectArgs().
    variadic,

    fn BuildSpec(ak: ExpectArgKind) type {
        return switch (ak) {
            .null => unreachable,
            .variadic => struct {},
            .int => struct { as: enum { i8, i16, i32, i64, isize, u8, u16, u32, u64, usize, zval } = .i64, optional: bool = false, nullable: bool = false },
            .float => struct { as: enum { f32, f64, zval } = .f64, optional: bool = false, nullable: bool = false },
            .string => struct { as: enum { string, cstr, str, zval } = .string, optional: bool = false, nullable: bool = false },
            .resource => struct { as: enum { value, stream, zval } = .value, optional: bool = false, nullable: bool = false },
            .mixed => struct { optional: bool = false, one_of: ?[]const ExpectArgKind = null },
            .object => struct { as: enum { value, zval } = .value, optional: bool = false, nullable: bool = false, instanceof: bool = false },
            .callable => struct { optional: bool = false, nullable: bool = false, resolve: bool = false },
            .reference => struct { optional: bool = false, kind: ?ExpectArgKind = null, as: enum { reference, zval, value } = .reference },
            else => struct { as: enum { value, zval } = .value, optional: bool = false, nullable: bool = false },
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
        variadic: BuildSpec(.variadic),

        pub fn isOptional(self: Spec) bool {
            return switch (self) {
                .null, .variadic => false,
                inline else => |m| m.optional,
            };
        }

        fn isZval(comptime self: Spec) bool {
            return switch (self) {
                .null, .mixed, .callable, .variadic => false,
                inline else => |s| s.as == .zval,
            };
        }
    };

    /// Runtime extension data for a single `Spec`.
    ///   - `.callable` with `.resolve = true`    → `struct { out: *zend.Callable }`
    ///   - `.callable` without resolve           → `void`
    ///   - `.object` with `.instanceof = true`   → `struct { class: *zend.ClassEntry }` (class/interface)
    ///   - `.object` without instanceof          → `void`
    ///   - all other specs                       → `void` (pass `{}`)
    pub fn Runtime(comptime spec: Spec) type {
        return switch (spec) {
            .callable => |s| if (s.resolve) struct { out: *zend.Callable } else void,
            .object => |s| if (s.instanceof) struct { class: *zend.ClassEntry } else void,
            else => void,
        };
    }

    inline fn toZvalKind(self: ExpectArgKind) Zval.Kind {
        return switch (self) {
            .reference, .mixed, .callable, .variadic => unreachable,
            inline else => |k| @field(Zval.Kind, @tagName(k)),
        };
    }

    fn expectedType(comptime self: ExpectArgKind, comptime nullable: bool) c.zend_expected_type {
        const name = switch (self) {
            .int => "LONG",
            .float => "DOUBLE",
            .string => "STRING",
            .bool => "BOOL",
            .array => "ARRAY",
            .object => "OBJECT",
            .resource => "RESOURCE",
            else => unreachable,
        };
        return @intCast(@field(c, "Z_EXPECTED_" ++ name ++ if (nullable) "_OR_NULL" else ""));
    }

    inline fn InnerType(self: ExpectArgKind) type {
        return Zval.Type(self.toZvalKind());
    }
};

fn ExpectArgValueType(comptime spec: ExpectArgKind.Spec) type {
    return switch (spec) {
        .int => |s| switch (s.as) {
            .i8 => i8,
            .i16 => i16,
            .i32 => i32,
            .i64 => i64,
            .isize => isize,
            .u8 => u8,
            .u16 => u16,
            .u32 => u32,
            .u64 => u64,
            .usize => usize,
            .zval => *Zval,
        },
        .float => |s| switch (s.as) {
            .f32 => f32,
            .f64 => f64,
            .zval => *Zval,
        },
        .string => |s| switch (s.as) {
            .string => []const u8,
            .cstr => [:0]const u8,
            .str => *zend.String,
            .zval => *Zval,
        },
        .resource => |s| switch (s.as) {
            .value => *zend.Resource,
            .stream => *Stream,
            .zval => *Zval,
        },
        .null, .mixed, .callable, .reference, .variadic => unreachable,
        inline else => if (spec.isZval()) *Zval else @as(ExpectArgKind, spec).InnerType(),
    };
}

pub fn ExpectArgResult(comptime spec: ExpectArgKind.Spec) type {
    return switch (spec) {
        .variadic => Variadic,
        .null => @compileError(".null cannot be used as a standalone type; use another type with the `nullable` flag or use .mixed with unions to allow null as a distinct case"),
        .mixed => |s| {
            const T = if (s.one_of) |kinds| Mixed(kinds) else *Zval;
            return if (s.optional) ?T else T;
        },
        .callable => |s| {
            const T = if (s.nullable) Nullable(*Zval) else *Zval;
            return if (s.optional) ?T else T;
        },
        .reference => |s| {
            if (s.kind) |kind| {
                if (kind == .reference or kind == .mixed or kind == .variadic) {
                    @compileError("invalid .reference.kind: use a value type or .callable; omit .kind to accept any referenced value");
                }
            }
            const T = switch (s.as) {
                .reference => *zend.Reference,
                .zval, .value => *Zval,
            };
            return if (s.optional) ?T else T;
        },
        inline else => |s| {
            const Value = ExpectArgValueType(spec);
            const T = if (s.nullable and !spec.isZval()) Nullable(Value) else Value;
            return if (s.optional) ?T else T;
        },
    };
}

/// A tagged PHP union, e.g. Mixed(&.{ .int, .string }).
/// Include .null to accept PHP null; an outer optional permits omitted arguments.
pub fn Mixed(comptime kinds: []const ExpectArgKind) type {
    if (kinds.len <= 1) @compileError("Mixed requires at least two types");
    const TagInt = @typeInfo(ExpectArgKind).@"enum".tag_type;
    var field_names: [kinds.len][]const u8 = undefined;
    var field_types: [kinds.len]type = undefined;
    var field_attrs: [kinds.len]std.lang.Type.Union.FieldAttributes = undefined;
    var field_values: [kinds.len]TagInt = undefined;
    inline for (kinds, 0..) |kind, i| {
        if (kind == .mixed or kind == .reference or kind == .callable or kind == .variadic) {
            @compileError("Mixed cannot contain ." ++ @tagName(kind));
        }
        for (kinds[0..i]) |prev| if (prev == kind) @compileError("Mixed contains duplicate type ." ++ @tagName(kind));
        field_names[i] = @tagName(kind);
        field_types[i] = kind.InnerType();
        field_attrs[i] = .{};
        field_values[i] = @backingInt(kind);
    }
    return @Union(
        .auto,
        @Enum(TagInt, .exhaustive, &field_names, &field_values),
        &field_names,
        &field_types,
        &field_attrs,
    );
}

/// Explicit PHP null (.null) or a typed value (.value), for nullable arguments
/// and handler returns. An outer Zig optional distinguishes omitted arguments.
/// expectArgs uses this for nullable typed outputs except `.as = .zval`.
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

/// Parse a present argument in the currently executing call, coercing its slot as needed.
pub inline fn extractValue(
    identifier: Identifier,
    zv: *c.zval,
    comptime spec: ExpectArgKind.Spec,
    runtime: ExpectArgKind.Runtime(spec),
) exception.Error!ExpectArgResult(spec) {
    switch (comptime spec) {
        .null, .variadic => unreachable,
        .mixed => |s| {
            if (comptime s.one_of) |unions| {
                const Result = ExpectArgResult(spec);
                const Union = if (comptime s.optional) @typeInfo(Result).optional.child else Result;
                comptime var php_union_type: []const u8 = "";
                inline for (unions) |kind| {
                    if (php_union_type.len > 0) php_union_type = php_union_type ++ "|";
                    php_union_type = php_union_type ++ @tagName(kind);
                    const zk = comptime kind.toZvalKind();
                    if (Zval.raw.is(zv, zk)) {
                        return @unionInit(Union, @tagName(kind), if (zk == .null) {} else Zval.raw.asUnchecked(zv, zk));
                    }
                }
                return identifier.kindError(php_union_type, zv);
            } else {
                return Zval.from(zv);
            }
        },
        .callable => |s| {
            const or_null = comptime if (s.nullable) " or null" else "";
            if (comptime s.nullable) if (Zval.raw.is(zv, .null)) return .null;
            if (comptime s.resolve) {
                var err: ?[*:0]u8 = null;
                runtime.out.parse(zv, &err) catch {
                    if (err) |e| {
                        defer if (comptime c.ZEND_DEBUG == 1) c._efree(@as(*anyopaque, @ptrCast(e)), @src().file.ptr, @intCast(@src().line), null, 0) else c.efree(@as(*anyopaque, @ptrCast(e)));
                        return identifier.typeError("must be a valid callback" ++ or_null ++ ", %s", .{e});
                    }
                    return identifier.typeError("must be a valid callback" ++ or_null, .{});
                };
            } else if (!zend.Callable.isCallable(zv)) {
                return identifier.typeError("must be a valid callback" ++ or_null, .{});
            }
            return if (comptime s.nullable) .{ .value = Zval.from(zv) } else Zval.from(zv);
        },
        .reference => |s| {
            if (!Zval.raw.is(zv, .reference)) return identifier.kindError("reference", zv);
            const ref = Zval.raw.asUnchecked(zv, .reference);
            if (comptime s.kind) |kind| {
                const value = ref.val();
                const matches = if (comptime kind == .callable)
                    zend.Callable.isCallable(value)
                else
                    Zval.raw.is(value, comptime kind.toZvalKind());
                if (!matches) return identifier.kindError(@tagName(kind), value);
            }
            return switch (comptime s.as) {
                .reference => ref,
                .zval => Zval.from(zv),
                .value => Zval.from(ref.val()),
            };
        },
        .object => |s| {
            if (comptime s.nullable) if (Zval.raw.is(zv, .null)) return if (comptime spec.isZval()) Zval.from(zv) else .null;
            if (!Zval.raw.is(zv, .object)) {
                if (comptime s.instanceof) return identifier.classError(runtime.class, s.nullable, zv);
                return identifier.expectedTypeError(comptime ExpectArgKind.expectedType(.object, s.nullable), zv);
            }
            const obj = Zval.raw.asUnchecked(zv, .object);
            if (comptime s.instanceof) {
                if (!obj.instanceof(runtime.class)) return identifier.classError(runtime.class, s.nullable, zv);
            }
            if (comptime spec.isZval()) return Zval.from(zv);
            return if (comptime s.nullable) .{ .value = obj } else obj;
        },
        inline else => |s| {
            const tag: ExpectArgKind = spec;
            if (comptime s.nullable) if (Zval.raw.is(zv, .null)) return if (comptime spec.isZval()) Zval.from(zv) else .null;
            if (!Zval.raw.is(zv, comptime tag.toZvalKind())) {
                try coerce(tag, identifier, zv, comptime ExpectArgKind.expectedType(tag, s.nullable));
            }
            if (comptime spec.isZval()) return Zval.from(zv);
            const raw = try extractTypedValue(identifier, zv, spec);
            return if (comptime s.nullable) .{ .value = raw } else raw;
        },
    }
}

/// Apply ZPP's slow path to a by-value argument slot owned by the call frame.
/// Keep conversion logic out of line to avoid expanding argument parsing's fast path.
noinline fn coerce(comptime kind: ExpectArgKind, identifier: Identifier, zv: *c.zval, expected: c.zend_expected_type) exception.Error!void {
    @branchHint(.cold);
    const arg_num = switch (identifier) {
        .position => |position| position,
        .name => blk: {
            const frame = globals.executor().currentCallFrame().?;
            const func = frame.function().?;
            break :blk func.fixedParamCount() + 1;
        },
    };
    switch (kind) {
        .int => {
            var value: c.zend_long = undefined;
            if (!c.zend_parse_arg_long_slow(zv, &value, arg_num)) return identifier.expectedTypeError(expected, zv);
            Zval.raw.release(zv);
            Zval.raw.set(zv, .int, value);
        },
        .float => {
            var value: f64 = undefined;
            if (!c.zend_parse_arg_double_slow(zv, &value, arg_num)) return identifier.expectedTypeError(expected, zv);
            Zval.raw.release(zv);
            Zval.raw.set(zv, .float, value);
        },
        .bool => {
            var value: bool = undefined;
            if (!c.zend_parse_arg_bool_slow(zv, &value, arg_num)) return identifier.expectedTypeError(expected, zv);
            Zval.raw.release(zv);
            Zval.raw.set(zv, .bool, value);
        },
        // Converts the slot in place, like Z_PARAM_STR.
        .string => {
            var value: [*c]c.zend_string = null;
            if (!c.zend_parse_arg_str_slow(zv, &value, arg_num)) return identifier.expectedTypeError(expected, zv);
        },
        else => return identifier.expectedTypeError(expected, zv),
    }
}

fn extractTypedValue(identifier: Identifier, zv: *c.zval, comptime spec: ExpectArgKind.Spec) exception.Error!ExpectArgValueType(spec) {
    const T = ExpectArgValueType(spec);
    return switch (comptime spec) {
        .int => std.math.cast(T, Zval.raw.asUnchecked(zv, .int)) orelse
            identifier.valueError("must be between " ++ comptime std.fmt.comptimePrint("{d} and {d} ({s})", .{ std.math.minInt(T), std.math.maxInt(T), @typeName(T) }), .{}),
        .float => blk: {
            const value = Zval.raw.asUnchecked(zv, .float);
            if (comptime T == f32) {
                if (std.math.isFinite(value) and @abs(value) > std.math.floatMax(f32)) {
                    return identifier.valueError("must be within the finite f32 range or be INF, -INF or NAN", .{});
                }
            }
            break :blk @as(T, @floatCast(value));
        },
        .string => |s| switch (s.as) {
            .string => Zval.raw.asUnchecked(zv, .string),
            .cstr => Zval.raw.asUnchecked(zv, .str).slice(),
            .str => Zval.raw.asUnchecked(zv, .str),
            .zval => Zval.from(zv),
        },
        .resource => |s| switch (s.as) {
            .value => Zval.raw.asUnchecked(zv, .resource),
            .stream => try Stream.fromResource(Zval.raw.asUnchecked(zv, .resource)),
            .zval => Zval.from(zv),
        },
        inline else => Zval.raw.asUnchecked(zv, comptime @as(ExpectArgKind, spec).toZvalKind()),
    };
}

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(Variadic);
    std.testing.refAllDecls(Identifier);
    std.testing.refAllDecls(ExpectArgKind);
}
