//! PHP function/method call context.
const c = @import("root.zig").c;
const ClassEntry = @import("zend/class_entry.zig").ClassEntry;
const Zval = @import("zval.zig").Zval;

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
/// Wraps `zend_execute_data` to provide type-safe parameter parsing
/// via `parse()`, argument counting, and scope/object introspection.
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

    /// Get the Nth argument (1-indexed) as a raw zval pointer.
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

    /// Parse function parameters according to a type specification.
    ///
    /// This function wraps PHP's zend_parse_parameters() to extract typed arguments
    /// from the PHP function call. It validates types and converts PHP values to
    /// the expected Zig types.
    ///
    /// Type Specification Format:
    ///   The type_spec string uses single characters to indicate expected types:
    ///
    ///   Basic Types:
    ///     - 'l' (long)    -> i64: PHP integer (requires 1 arg: &val)
    ///     - 'd' (double)  -> f64: PHP float (requires 1 arg: &val)
    ///     - 's' (string)  -> [*]u8 + size_t: PHP string (requires 2 args: &ptr, &len)
    ///     - 'b' (bool)    -> bool: PHP boolean (requires 1 arg: &val)
    ///     - 'z' (zval)    -> *c.zval: Raw PHP value, any type (requires 1 arg: &ptr)
    ///
    ///   Array and Object:
    ///     - 'a' (array)   -> *c.zval: PHP array zval (requires 1 arg: &ptr)
    ///     - 'h' (hashtable) -> *c.HashTable: PHP array/hashtable (requires 1 arg: &ptr)
    ///     - 'o' (object)  -> *c.zval: PHP object (requires 1 arg: &ptr)
    ///     - 'O' (typed object) -> *c.zval: Object of specific class (requires 2 args: &ptr, class_entry)
    ///
    ///   Optional Parameters:
    ///     - '|' : All parameters after this are optional
    ///     - '!' : The preceding parameter can be null
    ///
    ///   Examples:
    ///     - "ll"      : Two required integers
    ///     - "s"       : One required string (needs &ptr, &len)
    ///     - "sl"      : One string and one integer
    ///     - "l|s"     : One required integer, one optional string
    ///     - "z!"      : One nullable zval
    ///     - "s|l"     : One required string, one optional integer
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
    /// // --- Basic scalar types ---
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
    /// // 's': function(string $msg)  -- requires 2 args: &ptr, &len
    /// var msg: []u8 = undefined;
    /// try ctx.call.parse("s", .{ &msg.ptr, &msg.len });
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
    /// // --- Array and Hashtable ---
    ///
    /// // 'a': function(array $arr)
    /// var arr_zv: *c.zval = undefined;
    /// try ctx.call.parse("a", .{&arr_zv});
    /// const arr = arr_zv.value.arr; // extract zend_array*
    ///
    /// // 'h': function(array $map)  -- receives HashTable* directly
    /// var ht: *c.HashTable = undefined;
    /// try ctx.call.parse("h", .{&ht});
    ///
    /// // --- Object ---
    ///
    /// // 'o': function(object $obj)  -- any object
    /// var obj: *c.zval = undefined;
    /// try ctx.call.parse("o", .{&obj});
    ///
    /// // 'O': function(MyClass $obj)  -- specific class, requires 2 args: &ptr, class_entry
    /// var typed_obj: *c.zval = undefined;
    /// try ctx.call.parse("O", .{ &typed_obj, my_class_entry });
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

    /// Parse function parameters when no parameters are expected.
    ///
    /// This is a convenience function for functions that take no parameters.
    /// It validates that the argument count is zero and emits a PHP error
    /// message if arguments were provided.
    ///
    /// Returns:
    ///   Error.ParseFailure if any arguments were provided
    ///
    /// Example:
    /// ```zig
    /// fn helloWorld(ctx: Ctx) !void {
    ///     try ctx.call.parseNone();
    ///     ctx.ret.set(.string, "Hello, World!");
    /// }
    /// ```
    pub fn parseNone(self: *Call) Error!void {
        if (self.numArgs() != 0) {
            c.zend_wrong_parameters_none_error();
            return Error.ParseFailure;
        }
    }

    /// Parse method parameters (for class methods).
    ///
    /// This is similar to parse() but specifically for class methods. It handles
    /// the implicit $this parameter that all PHP methods have.
    ///
    /// Note: In most cases, you don't need to call this directly. The method
    /// wrapper automatically extracts the object instance. Use parse() instead.
    ///
    /// Parameters:
    ///   - type_spec: Type specification string (same format as parse())
    ///   - args: Tuple of pointers to receive the parsed values
    ///
    /// Returns:
    ///   Error.ParseFailure if parsing fails
    pub fn parseMethod(self: *Call, comptime type_spec: [:0]const u8, type_args: anytype) Error!void {
        if (@typeInfo(@TypeOf(args)) != .@"struct") {
            @compileError("parseMethod: args must be a tuple (use .{} syntax)");
        }
        var this_ptr: ?*c.zval = null;
        const result = @call(
            .auto,
            c.zend_parse_method_parameters,
            .{ self.numArgs(), self.this(), type_spec.ptr, &this_ptr } ++ type_args,
        );
        if (result == c.FAILURE) return Error.ParseFailure;
    }

    /// Get the $this object as a zval (for class methods).
    ///
    /// Returns the current object context when called from a method.
    /// Returns null when called from a static method or function.
    ///
    /// Returns:
    ///   The $this zval pointer, or null if not in an object context
    pub fn this(self: *Call) ?*c.zval {
        const this_zval = &self.ptr().This;
        if (Zval.native.getType(this_zval) == c.IS_OBJECT) {
            return this_zval;
        }
        return null;
    }

    /// Get the $this object as a zend_object (for class methods).
    ///
    /// This is the preferred way to access the object instance in methods,
    /// as it gives you direct access to the object structure.
    ///
    /// Returns:
    ///   The zend_object pointer, or null if not in an object context
    ///
    /// Example:
    /// ```zig
    /// fn myMethod(self: *MyClass, ctx: Ctx) !void {
    ///     // The wrapper already extracts 'self', but if you need raw access:
    ///     const obj = ctx.call.thisObject();
    /// }
    /// ```
    pub fn thisObject(self: *Call) ?*c.zend_object {
        return c.zend_get_this_object(self.ptr());
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
