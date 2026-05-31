//! PHP function/method call context.
const std = @import("std");

const c = @import("root.zig").c;
const errors = @import("errors.zig");
const ClassEntry = @import("zend/class_entry.zig").ClassEntry;
const zend = @import("zend/object.zig");
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
///     try ctx.call.parse("ll", .{ &a, &b });
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
/// `parse()` for complex type specs (callable, object, variadic, etc.).
pub const Call = opaque {
    /// Errors that can occur during parameter parsing
    pub const Error = error{
        /// Parameter parsing failed (wrong type, missing required param, etc.)
        ParseFailure,
    };

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
    pub inline fn numArgs(self: *Call) u32 {
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
        const count = self.numArgs();
        if (count == 0) return &[_]c.zval{};
        const base: [*]c.zval = @ptrCast(self.ptr());
        return base[c.ZEND_CALL_FRAME_SLOT..][0..count];
    }

    /// Validate the total number of arguments against expected min/max.
    /// Call once at the top of each function, before accessing individual args.
    /// max = 0 means unlimited.
    pub inline fn expectArgCount(self: *Call, comptime min: u32, comptime max: u32) errors.WrongParameterCountError!void {
        const count = self.numArgs();
        if (count < min or (max > 0 and count > max)) {
            return errors.wrongParameterCount(min, @max(count, max));
        }
    }

    /// Expect zero arguments. Calls zend_wrong_parameters_none_error on failure.
    pub inline fn expectNone(self: *Call) errors.WrongParameterCountError!void {
        if (self.numArgs() != 0) {
            return errors.wrongParametersNone();
        }
    }

    /// Error set for `expectArgs`: argument count mismatch, missing required argument, or type mismatch.
    pub const ExpectArgsError = ExpectArgError || errors.WrongParameterCountError;

    fn ExpectArgsType(comptime defs: []const ExpectArgDefinition) type {
        comptime {
            var types: [defs.len]type = undefined;
            for (defs, 0..) |def, i| {
                types[i] = ExpectArgType(def);
            }
            return @Tuple(&types);
        }
    }

    /// Extract all arguments with compile-time validation.
    /// Optionals must come after required args. min/max derived automatically.
    ///
    /// Each entry is an `ExpectArgDefinition`; beyond `expect_type` and `optional`,
    /// you can set `nullable` (accept null) or `zval` (return raw zval pointer).
    ///
    /// Example:
    /// ```zig
    /// const args = try self.expectArgs(&.{
    ///     .{ .expect_type = .string },
    ///     .{ .expect_type = .int, .optional = true },
    ///     .{ .expect_type = .int, .nullable = true },
    /// });
    /// const name: []const u8 = args[0];
    /// const age: ?i64 = args[1];
    /// const count: Nullable(i64) = args[2];
    /// ```
    pub inline fn expectArgs(
        self: *Call,
        comptime defs: []const ExpectArgDefinition,
    ) ExpectArgsError!ExpectArgsType(defs) {
        comptime {
            var seen_optional = false;
            for (defs) |opt| {
                if (seen_optional and !opt.optional) {
                    @compileError("required argument after optional");
                }
                if (opt.optional) seen_optional = true;
            }
        }

        const min = comptime min: {
            var count: u32 = 0;
            for (defs) |opt| {
                if (!opt.optional) count += 1;
            }
            break :min count;
        };
        const max: u32 = @intCast(defs.len);

        try self.expectArgCount(min, max);

        const Result = ExpectArgsType(defs);
        var result: Result = undefined;
        inline for (defs, 0..) |opt, i| {
            result[i] = try self.expectArg(@intCast(i + 1), opt);
        }
        return result;
    }

    /// Error set for `expectArg` / `expectArgs`: missing required argument or type mismatch.
    pub const ExpectArgError = errors.ArgumentCountError || errors.ArgumentTypeError;

    /// Configuration for a single argument in `expectArg` / `expectArgs`.
    pub const ExpectArgDefinition = struct {
        /// Expected PHP type for this argument.
        expect_type: Zval.Kind,
        /// When true, argument may be omitted (returns null).
        optional: bool = false,

        // These options are only valid when expect_type != .mixed:

        /// When true, allows null in addition to the expected type (cannot be .mixed).
        nullable: bool = false,
        /// When true, returns the raw zval pointer instead of converting to a Zig type (cannot be .mixed).
        zval: bool = false,
    };

    /// Returned when `nullable` is set: distinguishes "null was passed" (.null) from "argument omitted" (?T).
    pub fn Nullable(comptime T: type) type {
        return union(enum) { null, value: T };
    }

    /// Compute the Zig return type for a single argument definition.
    fn ExpectArgType(comptime def: ExpectArgDefinition) type {
        comptime {
            const T = if (def.zval)
                *c.zval
            else if (def.expect_type != .mixed and def.nullable)
                Nullable(Zval.Type(def.expect_type))
            else
                Zval.Type(def.expect_type);
            return if (def.optional) ?T else T;
        }
    }

    /// Extract and type-check argument N (1-indexed). Must call expectArgCount first.
    /// When optional is true, returns null if the argument was not passed.
    ///
    /// See `ExpectArgDefinition` for the full set of options (`nullable`, `zval`).
    /// When using `expectArgs`, this is called automatically — prefer `expectArgs` for multi-arg cases.
    pub inline fn expectArg(
        self: *Call,
        n: u32,
        comptime def: ExpectArgDefinition,
    ) ExpectArgError!ExpectArgType(def) {
        comptime {
            if (def.expect_type == .mixed and (def.nullable or def.zval)) {
                @compileError("arg[" ++ n ++ "] invalid ExpectArgDefinition: 'mixed' cannot be nullable or a raw zval");
            }
        }

        if (n > self.numArgs()) {
            return if (comptime def.optional)
                null
            else
                errors.argumentCountError("missing required argument #%d", .{n});
        }

        const zv = self.arg(n);

        if (comptime def.expect_type == .mixed) {
            return zv; // no type checking for 'mixed'
        }

        // Nullable
        if (comptime def.nullable) {
            if (native.is(zv, .null)) return .null; // early return for null case
            if (native.is(zv, def.expect_type)) {
                return .{ .value = if (comptime def.zval) zv else native.asUnchecked(zv, def.expect_type) };
            } else {
                return errors.argumentTypeError(n, "must be of type %s or null, %s given", .{ @tagName(def.expect_type).ptr, @tagName(native.kind(zv)).ptr });
            }
        }

        // Regular type check
        if (native.is(zv, def.expect_type)) {
            return if (comptime def.zval) zv else native.asUnchecked(zv, def.expect_type);
        } else {
            return errors.argumentTypeError(n, "must be of type %s, %s given", .{ @tagName(def.expect_type).ptr, @tagName(native.kind(zv)).ptr });
        }
    }

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
    /// try ctx.call.parse("l", .{&n});
    ///
    /// // 'd': function(float $x)
    /// var x: f64 = undefined;
    /// try ctx.call.parse("d", .{&x});
    ///
    /// // 'b': function(bool $flag)
    /// var flag: bool = undefined;
    /// try ctx.call.parse("b", .{&flag});
    ///
    /// // --- String types ---
    ///
    /// // 's': function(string $msg)  -- requires 2 args: &ptr, &len
    /// var msg: []u8 = undefined;
    /// try ctx.call.parse("s", .{ &msg.ptr, &msg.len });
    ///
    /// // 'S': function(string $msg)  -- receives zend_string* directly (1 arg)
    /// var zs: *c.zend_string = undefined;
    /// try ctx.call.parse("S", .{&zs});
    /// const s = zs.val()[0..zs.len];
    ///
    /// // 'p': function(string $path)  -- like 's' but rejects null bytes
    /// var path: []u8 = undefined;
    /// try ctx.call.parse("p", .{ &path.ptr, &path.len });
    ///
    /// // 'P': function(string $path)  -- like 'S' but rejects null bytes
    /// var zp: *c.zend_string = undefined;
    /// try ctx.call.parse("P", .{&zp});
    ///
    /// // --- Raw zval (any type) ---
    ///
    /// // 'z': function(mixed $val)
    /// var raw: *c.zval = undefined;
    /// try ctx.call.parse("z", .{&raw});
    /// const val = Zval.from(raw);
    /// if (val.is(.int)) {
    ///     const num = val.asUnchecked(.int);
    ///     _ = num;
    /// }
    ///
    /// // 'n': function(mixed $val = null)  -- allows null (PHP 8.1+)
    /// var nraw: *c.zval = undefined;
    /// try ctx.call.parse("n", .{&nraw});
    ///
    /// // --- Array and Hashtable ---
    ///
    /// // 'a': function(array $arr)
    /// var arr_zv: *c.zval = undefined;
    /// try ctx.call.parse("a", .{&arr_zv});
    /// const arr = arr_zv.value.arr; // extract zend_array*
    ///
    /// // 'A': function(array $arr)  -- like 'a', already dereferenced
    /// var arr_zv2: *c.zval = undefined;
    /// try ctx.call.parse("A", .{&arr_zv2});
    ///
    /// // 'h': function(array $map)  -- receives HashTable* directly
    /// var ht: *c.HashTable = undefined;
    /// try ctx.call.parse("h", .{&ht});
    ///
    /// // 'H': function(array $map)  -- like 'h', already dereferenced
    /// var ht2: *c.HashTable = undefined;
    /// try ctx.call.parse("H", .{&ht2});
    ///
    /// // --- Object / Class ---
    ///
    /// // 'o': function(object $obj)  -- any object
    /// var obj: *c.zval = undefined;
    /// try ctx.call.parse("o", .{&obj});
    ///
    /// // 'O': function(MyClass $obj)  -- specific class, requires 2 args: &ptr, class_entry
    /// var typed_obj: *c.zval = undefined;
    /// try ctx.call.parse("O", .{ &typed_obj, my_class_entry });
    ///
    /// // 'C': function(string $class)  -- receives zend_class_entry* directly
    /// var ce: *c.zend_class_entry = undefined;
    /// try ctx.call.parse("C", .{&ce});
    ///
    /// // --- Callable ---
    ///
    /// // 'f': function(callable $cb)  -- requires 2 args
    /// var fci: c.zend_fcall_info = undefined;
    /// var fcc: c.zend_fcall_info_cache = undefined;
    /// try ctx.call.parse("f", .{ &fci, &fcc });
    ///
    /// // --- Resource ---
    ///
    /// // 'r': function(resource $handle)
    /// var res: *c.zval = undefined;
    /// try ctx.call.parse("r", .{&res});
    ///
    /// // --- Mixed types ---
    ///
    /// // 'sl': function(string $name, int $count)
    /// var name: []u8 = undefined;
    /// var count: i64 = undefined;
    /// try ctx.call.parse("sl", .{ &name.ptr, &name.len, &count });
    ///
    /// // --- Optional and nullable ---
    ///
    /// // 's|l': function(string $key, int $ttl = 0)  -- caller sets default
    /// var key: []u8 = undefined;
    /// var ttl: i64 = 0;
    /// try ctx.call.parse("s|l", .{ &key.ptr, &key.len, &ttl });
    ///
    /// // 's|z!': function(string $name, ?int $age = null)
    /// var person_name: []u8 = undefined;
    /// var age_opt: Zval.Optional = .init;
    /// try ctx.call.parse("s|z!", .{ &person_name.ptr, &person_name.len, &age_opt.ptr });
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
    /// try ctx.call.parse("s/", .{ &cow_msg.ptr, &cow_msg.len });
    ///
    /// // --- Variadic ---
    ///
    /// // 'z*': function(mixed ...$args)  -- 0 or more variadic arguments
    /// var first: *c.zval = undefined;
    /// var rest: [*]c.zval = undefined;
    /// var rest_count: u32 = undefined;
    /// try ctx.call.parse("z*", .{ &first, &rest, &rest_count });
    ///
    /// // '+': function(mixed $first, mixed ...$args)  -- 1 or more variadic arguments
    /// var fst: [*]c.zval = undefined;
    /// var rst_count: u32 = undefined;
    /// try ctx.call.parse("+", .{ &fst, &rst_count });
    /// ```
    pub fn parse(self: *Call, comptime type_spec: [:0]const u8, type_args: anytype) Error!void {
        if (@typeInfo(@TypeOf(type_args)) != .@"struct") {
            @compileError("parse: args must be a tuple (use .{} syntax)");
        }
        const result = @call(
            .auto,
            c.zend_parse_parameters,
            .{ self.numArgs(), type_spec.ptr } ++ type_args,
        );
        if (result == c.FAILURE) return Error.ParseFailure;
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
