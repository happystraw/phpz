//! Zval - PHP Value Wrapper
//!
//! Zval is a wrapper around PHP's zval (Zend Value) structure, providing
//! type-safe access to PHP values from Zig code.
//!
//! A zval can hold any PHP value: integers, floats, strings, booleans, arrays,
//! objects, resources, references, or null/undefined.
//!
//! ## Basic Usage
//!
//! Reading values from PHP:
//! ```zig
//! fn readValue(ctx: *ExecContext, ret: *Zval) !void {
//!     var input: i64 = undefined;
//!     try ctx.parse("l", .{&input});
//!
//!     // Return a value to PHP
//!     ret.set(.int, input * 2);
//! }
//! ```
//!
//! Type checking and conversion:
//! ```zig
//! fn processValue(zval: *Zval) void {
//!     if (zval.is(.int)) {
//!         const num = zval.asUnchecked(.int);
//!         // Process integer...
//!     } else if (zval.is(.string)) {
//!         const str = zval.asUnchecked(.string);
//!         // Process string...
//!     }
//! }
//! ```

const Zval = @This();

/// The underlying PHP zval pointer
inner: *c.zval,

/// Errors that can occur during zval operations
pub const Error = error{
    /// Type mismatch when attempting type conversion
    TypeMismatch,
};

/// PHP value types that can be stored in a zval.
///
/// This enum represents all possible PHP value types, mapped to Zig-friendly names.
pub const Kind = enum {
    /// Undefined value (uninitialized variable)
    undef,
    /// PHP null value
    null,
    /// PHP integer (always 64-bit in PHP 8+)
    int,
    /// PHP float (double precision)
    float,
    /// PHP string (binary-safe, reference-counted)
    string,
    /// PHP boolean (true or false)
    bool,
    /// PHP array (ordered hashmap)
    array,
    /// PHP object instance
    object,
    /// PHP resource (external resource handle)
    resource,
    /// PHP reference (indirect zval pointer)
    reference,
    /// Mixed type (union or anytype, represents any PHP value)
    mixed,
};

/// Get the corresponding Zig type for a PHP value kind.
///
/// This function maps PHP types to their Zig equivalents for type-safe access.
///
/// Type Mappings:
///   - undef, null -> void (no value)
///   - int -> i64 (PHP integers are always 64-bit)
///   - float -> f64 (PHP floats are double precision)
///   - string -> []const u8 (byte slice)
///   - bool -> bool
///   - array -> *c.zend_array (PHP array structure)
///   - object -> *c.zend_object (PHP object structure)
///   - resource -> *c.zend_resource (resource handle)
///   - reference -> *c.zend_reference (reference structure)
///   - mixed -> *c.zval (raw zval pointer)
///
/// Example:
/// ```zig
/// const IntType = Zval.Type(.int); // i64
/// const StrType = Zval.Type(.string); // []const u8
/// ```
pub fn Type(comptime zk: Kind) type {
    return switch (zk) {
        .undef, .null => void,
        .int => i64,
        .float => f64,
        .string => []const u8,
        .bool => bool,
        .array => *c.zend_array,
        .object => *c.zend_object,
        .resource => *c.zend_resource,
        .reference => *c.zend_reference,
        .mixed => *c.zval,
    };
}

/// Get the PHP type ID of a raw zval.
///
/// Returns the internal PHP type constant (IS_LONG, IS_STRING, etc.).
/// Use kind() or is() for type checking in most cases instead.
///
/// Parameters:
///   - zv: Raw zval pointer
///
/// Returns:
///   The PHP type ID (u8)
pub fn phpType(zv: *c.zval) u8 {
    return c.zval_get_type(zv);
}

/// Get the PHP type name of a raw zval as a C string.
///
/// Returns a human-readable type name like "integer", "string", "array", etc.
/// Useful for error messages.
///
/// Parameters:
///   - zv: Raw zval pointer
///
/// Returns:
///   Null-terminated string with the type name
///
/// Example:
/// ```zig
/// const type_name = Zval.phpTypeName(zv);
/// std.debug.print("Got type: {s}\n", .{type_name});
/// ```
pub fn phpTypeName(zv: *c.zval) [*:0]const u8 {
    return c.zend_zval_type_name(zv);
}

/// Create a Zval wrapper from a raw zval pointer.
///
/// This is typically used internally by the function/method wrapper,
/// but can be used to wrap existing zval pointers.
///
/// Parameters:
///   - zv: Raw zval pointer
///
/// Returns:
///   A Zval wrapper
pub fn from(zv: *c.zval) Zval {
    return .{ .inner = zv };
}

/// Get the type (Kind) of this zval.
///
/// Returns:
///   The PHP value kind
///
/// Example:
/// ```zig
/// const k = zval.kind();
/// if (k == .int) {
///     // It's an integer
/// }
/// ```
pub fn kind(self: *const Zval) Kind {
    return switch (phpType(self.inner)) {
        c.IS_UNDEF => .undef,
        c.IS_NULL => .null,
        c.IS_LONG => .int,
        c.IS_DOUBLE => .float,
        c.IS_STRING => .string,
        c.IS_TRUE, c.IS_FALSE => .bool,
        c.IS_ARRAY => .array,
        c.IS_OBJECT => .object,
        c.IS_RESOURCE => .resource,
        c.IS_REFERENCE => .reference,
        else => .mixed, // fallback for unknown types
    };
}

/// Check if this zval is of a specific type.
///
/// This is the preferred way to check zval types before conversion.
///
/// Parameters:
///   - zk: The kind to check against
///
/// Returns:
///   true if the zval is of the specified kind
///
/// Example:
/// ```zig
/// if (zval.is(.int)) {
///     const num = zval.asUnchecked(.int);
///     // Safe to use num as i64
/// }
///
/// if (zval.is(.string)) {
///     const str = zval.asUnchecked(.string);
///     // Safe to use str as []const u8
/// }
/// ```
pub fn is(self: *const Zval, comptime zk: Kind) bool {
    const t = phpType(self.inner);
    return switch (zk) {
        .undef => t == c.IS_UNDEF,
        .null => t == c.IS_NULL,
        .int => t == c.IS_LONG,
        .float => t == c.IS_DOUBLE,
        .bool => t == c.IS_TRUE or t == c.IS_FALSE,
        .string => t == c.IS_STRING,
        .array => t == c.IS_ARRAY,
        .object => t == c.IS_OBJECT,
        .resource => t == c.IS_RESOURCE,
        .reference => t == c.IS_REFERENCE,
        .mixed => t != c.IS_UNDEF,
    };
}

/// Convert this zval to a Zig value with type checking.
///
/// This function performs runtime type checking and returns an error if
/// the zval is not of the expected type.
///
/// Parameters:
///   - zt: The kind to convert to
///
/// Returns:
///   The converted value, or Error.TypeMismatch if types don't match
///
/// Example:
/// ```zig
/// // Safe conversion with error handling
/// const num = zval.as(.int) catch |err| {
///     std.debug.print("Expected integer, got {s}\n", .{zval.kind()});
///     return err;
/// };
/// ```
pub fn as(self: *const Zval, comptime zt: Kind) Error!Type(zt) {
    if (!self.is(zt)) return Error.TypeMismatch;
    return self.asUnchecked(zt);
}

/// Convert this zval to a Zig value without type checking.
///
/// **WARNING**: This function does NOT check the type. Using it with the wrong
/// type will cause undefined behavior. Always use is() to check the type first,
/// or use as() for automatic type checking.
///
/// Parameters:
///   - zk: The kind to convert to
///
/// Returns:
///   The converted value (undefined behavior if type is wrong)
///
/// Example:
/// ```zig
/// // SAFE: Type checked first
/// if (zval.is(.int)) {
///     const num = zval.asUnchecked(.int); // Safe because we checked
/// }
///
/// // UNSAFE: No type check
/// const num = zval.asUnchecked(.int); // Undefined behavior if not an int!
/// ```
pub fn asUnchecked(self: *const Zval, comptime zk: Kind) Type(zk) {
    return switch (zk) {
        .undef, .null => @compileError(std.fmt.comptimePrint(
            "'{s}' has no value to convert - use 'is(.{s})' to check the type instead",
            .{ @tagName(zk), @tagName(zk) },
        )),
        .int => self.inner.value.lval,
        .float => self.inner.value.dval,
        .string => blk: {
            const zend_str = self.inner.value.str;
            break :blk @as([*]const u8, @ptrCast(&zend_str.*.val))[0..zend_str.*.len];
        },
        .bool => phpType(self.inner) == c.IS_TRUE,
        .array => self.inner.value.arr orelse unreachable,
        .object => self.inner.value.obj orelse unreachable,
        .resource => self.inner.value.res orelse unreachable,
        .reference => self.inner.value.ref orelse unreachable,
        .mixed => self.inner,
    };
}

/// Convert this zval to a Zig value, or return a default value on type mismatch.
///
/// This is a convenience function that combines as() with a fallback default value.
///
/// Parameters:
///   - zk: The kind to convert to
///   - default: The default value to return if type doesn't match
///
/// Returns:
///   The converted value, or the default value if type doesn't match
///
/// Example:
/// ```zig
/// // Get integer, or use 0 if not an integer
/// const num = zval.asOrDefault(.int, 0);
///
/// // Get string, or use empty string if not a string
/// const str = zval.asOrDefault(.string, "");
/// ```
pub fn asOrDefault(self: *const Zval, comptime zk: Kind, default: Type(zk)) Type(zk) {
    return self.as(zk) catch default;
}

/// Set this zval to a specific value.
///
/// This function sets the zval's type and value. It handles the PHP type tagging
/// and value storage automatically.
///
/// Parameters:
///   - zk: The kind of value to set
///   - val: The value to store
///
/// Example:
/// ```zig
/// fn myFunction(ctx: *ExecContext, ret: *Zval) !void {
///     // Return an integer
///     ret.set(.int, 42);
///
///     // Return a string
///     ret.set(.string, "Hello, PHP!");
///
///     // Return a boolean
///     ret.set(.bool, true);
///
///     // Return null
///     ret.set(.null, {});
///
///     // Return a float
///     ret.set(.float, 3.14);
/// }
/// ```
///
/// Special cases:
///   - For .string: The string is automatically copied and reference-counted by PHP
///   - For .undef and .null: The val parameter should be {} (void value)
///   - For .array, .object, .resource: Pass the appropriate pointer type
pub fn set(self: *Zval, comptime zk: Kind, val: Type(zk)) void {
    switch (zk) {
        .undef => {
            self.inner.u1.type_info = c.IS_UNDEF;
        },
        .null => {
            self.inner.u1.type_info = c.IS_NULL;
        },
        .int => {
            self.inner.value.lval = @intCast(val);
            self.inner.u1.type_info = c.IS_LONG;
        },
        .float => {
            self.inner.value.dval = @floatCast(val);
            self.inner.u1.type_info = c.IS_DOUBLE;
        },
        .string => {
            const str: zend.String = .init(val);
            self.inner.value.str = str.inner;
            self.inner.u1.type_info = if (str.isInterned()) c.IS_INTERNED_STRING_EX else c.IS_STRING_EX;
        },
        .bool => {
            self.inner.u1.type_info = if (val) c.IS_TRUE else c.IS_FALSE;
        },
        .array => {
            self.inner.value.arr = val;
            self.inner.u1.type_info = c.IS_ARRAY_EX;
        },
        .object => {
            self.inner.value.obj = val;
            self.inner.u1.type_info = c.IS_OBJECT_EX;
        },
        .resource => {
            self.inner.value.res = val;
            self.inner.u1.type_info = c.IS_RESOURCE_EX;
        },
        .reference => {
            self.inner.value.ref = val;
            self.inner.u1.type_info = c.IS_REFERENCE_EX;
        },
        .mixed => {
            self.inner = val;
        },
    }
}

/// Convert this zval to a high-level wrapper type.
///
/// This function converts the zval to specialized wrapper types like Array or Object
/// which provide more convenient APIs for working with complex PHP values.
///
/// Supported types:
///   - Array: PHP array wrapper with element access
///   - Object: PHP object wrapper with property access
///
/// Parameters:
///   - T: The wrapper type to convert to
///
/// Returns:
///   The wrapper instance, or an error if conversion fails
///
/// Example:
/// ```zig
/// // Convert to Array wrapper
/// const arr = try zval.to(Zval.Array);
///
/// // Convert to Object wrapper
/// const obj = try zval.to(Zval.Object);
/// ```
pub inline fn to(self: *Zval, comptime T: type) !T {
    return switch (T) {
        Array => Array.from(self.inner),
        Object => Object.from(self.inner),
        else => @compileError("Type '" ++ @typeName(T) ++ "' is not supported for from()"),
    };
}

/// Initialize this zval with a new instance of a wrapper type.
///
/// This function creates a new empty instance of a complex PHP type (array or object)
/// and stores it in this zval.
///
/// Supported types:
///   - Array: Creates a new empty PHP array
///   - Object: Creates a new stdClass object
///
/// Parameters:
///   - T: The wrapper type to initialize
///
/// Returns:
///   The wrapper instance for the newly created value
pub inline fn init(self: *Zval, comptime T: type) T {
    return switch (T) {
        Array => Array.empty(self.inner),
        Object => Object.init(self.inner),
        else => @compileError("Type '" ++ @typeName(T) ++ "' is not supported for init()"),
    };
}

/// Optional zval wrapper for handling nullable PHP parameters.
///
/// This structure is used when parsing optional parameters that can be null.
/// It wraps a potentially-null zval pointer and provides convenience methods
/// for checking and unwrapping the value.
///
/// Usage pattern:
/// ```zig
/// fn myFunction(ctx: *ExecContext, ret: *Zval) !void {
///     var required_name: []u8 = undefined;
///     var optional_age: Zval.Optional = .init;
///
///     // 's' = required string, '|' = following params optional, 'z!' = nullable zval
///     try ctx.parse("s|z!", .{ &required_name.ptr, &required_name.len, &optional_age.inner });
///
///     // Check if the optional parameter was provided
///     if (optional_age.unwrap()) |age_zval| {
///         if (age_zval.is(.int)) {
///             const age = age_zval.asUnchecked(.int);
///             std.debug.print("Age: {d}\n", .{age});
///         } else if (age_zval.is(.null)) {
///             std.debug.print("Age is null\n", .{});
///         }
///     } else {
///         std.debug.print("Age parameter not provided\n", .{});
///     }
/// }
/// ```
pub const Optional = struct {
    /// The underlying zval pointer (null if parameter not provided)
    inner: ?*c.zval = null,

    /// A constant for initializing Optional values
    pub const init: Optional = .{};

    /// Check if the parameter was provided (not null pointer).
    ///
    /// Note: This checks if the parameter exists, not if its value is null.
    /// A provided null value will return true here.
    ///
    /// Returns:
    ///   true if the parameter was provided
    pub fn isSome(self: *const Optional) bool {
        return self.inner != null;
    }

    /// Check if the parameter was not provided (null pointer).
    ///
    /// Returns:
    ///   true if the parameter was not provided
    pub fn isNone(self: *const Optional) bool {
        return self.inner == null;
    }

    /// Unwrap the optional to get the zval, if present.
    ///
    /// Returns:
    ///   A Zval wrapper if the parameter was provided, null otherwise
    ///
    /// Example:
    /// ```zig
    /// if (optional.unwrap()) |zval| {
    ///     // Parameter was provided (but might still be null value)
    ///     if (zval.is(.null)) {
    ///         std.debug.print("Got null value\n", .{});
    ///     } else {
    ///         // Process the value
    ///     }
    /// } else {
    ///     // Parameter was not provided at all
    ///     std.debug.print("Parameter not provided\n", .{});
    /// }
    /// ```
    pub fn unwrap(self: *const Optional) ?Zval {
        return if (self.inner) |v| .{ .inner = v } else null;
    }
};

const std = @import("std");

const c = @import("root.zig").c;
const zend = @import("zend.zig");
pub const Array = @import("Zval/Array.zig");
pub const Object = @import("Zval/Object.zig");
