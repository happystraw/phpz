const c = @import("root.zig").c;
const Zval = @import("zval.zig").Zval;

/// Call Frame for PHP Functions and Methods
///
/// CallFrame provides access to the current PHP call frame, allowing
/// you to parse function parameters, access the current object (in methods),
/// and retrieve scope information.
///
/// This is a core type used in PHP function/method bindings to interact with
/// the PHP runtime and extract parameters passed from PHP code.
///
/// Example:
/// ```zig
/// fn myFunction(frame: *CallFrame, ret: *Zval) !void {
///     var name: []u8 = undefined;
///     var age: i64 = undefined;
///     try frame.parse("sl", .{ &name.ptr, &name.len, &age });
///
///     const greeting = try std.fmt.allocPrint(allocator,
///         "Hello {s}, you are {d} years old!", .{name, age});
///     defer allocator.free(greeting);
///     ret.set(.string, greeting);
/// }
/// ```
pub const CallFrame = opaque {
    /// Errors that can occur during parameter parsing
    pub const Error = error{
        /// Parameter parsing failed (wrong type, missing required param, etc.)
        ParseFailure,
    };

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

    /// Get the number of arguments passed to the current function/method.
    ///
    /// Returns:
    ///   The argument count
    pub inline fn argCount(self: *CallFrame) u32 {
        return self.ptr().This.u2.num_args;
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
    ///     - 'l' (long)    -> i64: PHP integer
    ///     - 'd' (double)  -> f64: PHP float
    ///     - 's' (string)  -> [*]u8 + size_t: PHP string (requires 2 args: &ptr, &len)
    ///     - 'b' (bool)    -> bool: PHP boolean
    ///     - 'z' (zval)    -> *c.zval: Raw PHP value (any type)
    ///
    ///   Array and Object:
    ///     - 'a' (array)   -> *c.zend_array: PHP array
    ///     - 'h' (hashtable) -> *c.HashTable: PHP array/hashtable
    ///     - 'o' (object)  -> *c.zval: PHP object
    ///     - 'O' (typed object) -> *c.zval: Object of specific class
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
    /// // Parse two integers: function(int $a, int $b)
    /// var a: i64 = undefined;
    /// var b: i64 = undefined;
    /// try frame.parse("ll", .{ &a, &b });
    ///
    /// // Parse string and optional integer: function(string $name, int $age = null)
    /// var name: []u8 = undefined;
    /// var age_opt: Zval.Optional = .init;
    /// try frame.parse("s|z!", .{ &name.ptr, &name.len, &age_opt.ptr });
    /// if (age_opt.unwrap()) |age_zval| {
    ///     if (age_zval.is(.int)) {
    ///         const age = age_zval.asUnchecked(.int);
    ///     }
    /// }
    ///
    /// // Parse string only: function(string $message)
    /// var message: []u8 = undefined;
    /// try frame.parse("s", .{ &message.ptr, &message.len });
    /// ```
    pub fn parse(self: *CallFrame, comptime type_spec: [:0]const u8, args: anytype) Error!void {
        if (@typeInfo(@TypeOf(args)) != .@"struct") {
            @compileError("parse: args must be a tuple (use .{} syntax)");
        }
        const result = @call(
            .auto,
            c.zend_parse_parameters,
            .{ self.argCount(), type_spec.ptr } ++ args,
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
    /// fn helloWorld(frame: *CallFrame, ret: *Zval) !void {
    ///     try frame.parseNone();
    ///     ret.set(.string, "Hello, World!");
    /// }
    /// ```
    pub fn parseNone(self: *CallFrame) Error!void {
        if (self.argCount() != 0) {
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
    pub fn parseMethod(self: *CallFrame, comptime type_spec: [:0]const u8, args: anytype) Error!void {
        if (@typeInfo(@TypeOf(args)) != .@"struct") {
            @compileError("parseMethod: args must be a tuple (use .{} syntax)");
        }
        var this_ptr: ?*c.zval = null;
        const result = @call(
            .auto,
            c.zend_parse_method_parameters,
            .{ self.argCount(), self.this(), type_spec.ptr, &this_ptr } ++ args,
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
    pub fn this(self: *CallFrame) ?*c.zval {
        const this_zval = &self.ptr().This;
        if (Zval.raw.getType(this_zval) == c.IS_OBJECT) {
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
    /// fn myMethod(self: *MyClass, frame: *CallFrame, ret: *Zval) !void {
    ///     // The wrapper already extracts 'self', but if you need raw access:
    ///     const obj = frame.thisObject();
    /// }
    /// ```
    pub fn thisObject(self: *CallFrame) ?*c.zend_object {
        return c.zend_get_this_object(self.ptr());
    }

    /// Get the scope (class) where the current function was defined.
    ///
    /// Returns the class entry of the class that defines the current method.
    /// Returns null for non-method contexts.
    ///
    /// Returns:
    ///   The zend_class_entry pointer, or null if not in a class context
    pub fn scope(self: *CallFrame) ?*c.zend_class_entry {
        return @ptrCast(self.ptr().func.*.common.scope);
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
    ///   The zend_class_entry pointer of the called class
    pub fn calledScope(self: *CallFrame) ?*c.zend_class_entry {
        return @ptrCast(c.zend_get_called_scope(self.ptr()));
    }
};

test {
    @import("std").testing.refAllDecls(CallFrame);
}
