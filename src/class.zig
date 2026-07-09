//! PHP class registration and object lifecycle management.
//!
//! This module provides utilities for creating PHP classes from Zig types:
//!
//! - `Class`: Full-featured class wrapper with Zig data binding and lifecycle management
//! - `SimpleClass`: Lightweight class and method registration without Zig data binding
//!
//! Both functions generate class wrappers that integrate with PHP's object system,
//! handling registration through auto-generated `register_class_*` functions from
//! PHP stub files.

const std = @import("std");

const function_helper = @import("function.zig");
const phpz = @import("root.zig");
const c = phpz.c;
const zend = @import("zend.zig");
const Zval = @import("zval.zig").Zval;
const native = Zval.native;

/// PHP object handler overrides.
///
/// Define a `phpz.ObjectHandlers` with the handlers you want to override, then
/// pass it to the generated class's `setObjectHandlers` function. Only non-null
/// fields will replace the default std_object_handlers entries.
///
/// Example:
/// ```zig
/// const myHandlers = phpz.ObjectHandlers{ .clone_obj = &myClone };
/// StudentClass.setObjectHandlers(myHandlers);
/// ```
pub const ObjectHandlers = struct {
    /// __clone(): void  —  triggered by `clone $obj`
    clone_obj: c.zend_object_clone_obj_t = null,
    /// offsetGet($offset): mixed  —  ArrayAccess
    read_dimension: c.zend_object_read_dimension_t = null,
    /// offsetSet($offset, $value): void  —  ArrayAccess
    write_dimension: c.zend_object_write_dimension_t = null,
    /// offsetExists($offset): bool  —  ArrayAccess
    has_dimension: c.zend_object_has_dimension_t = null,
    /// offsetUnset($offset): void  —  ArrayAccess
    unset_dimension: c.zend_object_unset_dimension_t = null,
    /// get_object_vars($obj) / `foreach` properties
    get_properties: c.zend_object_get_properties_t = null,
    /// (settype) / (string) / (int) / (bool)  —  type casting
    cast_object: c.zend_object_cast_t = null,
    /// count($obj): int  —  Countable
    count_elements: c.zend_object_count_elements_t = null,
    /// var_dump($obj): array  —  debug info
    get_debug_info: c.zend_object_get_debug_info_t = null,
    /// operator overloading: + - * / etc.
    do_operation: c.zend_object_do_operation_t = null,
    /// $a == $b / $a > $b / $a <=> $b  —  comparison
    compare: c.zend_object_compare_t = null,
    /// $obj->prop = &$ref  —  reference property support
    get_property_ptr_ptr: c.zend_object_get_property_ptr_ptr_t = null,
    /// Closure::fromCallable($obj) / arrow functions
    get_closure: c.zend_object_get_closure_t = null,
    /// gc_collect_cycles()  —  circular reference tracking
    get_gc: c.zend_object_get_gc_t = null,
    /// get_properties_for()  —  PHP 8.1+ property purposes (var_dump, json, etc.)
    get_properties_for: c.zend_object_get_properties_for_t = null,
};

/// Create a PHP class wrapper around a Zig type.
///
/// This function generates a wrapper structure that bridges Zig code with PHP's
/// object system. The wrapper handles object lifecycle (allocation, initialization,
/// destruction) and provides methods for registering the class and its methods.
///
/// The generated wrapper structure layout:
/// ```
/// extern struct {
///     impl: T,               // Your Zig data structure
///     std: zend_object,      // PHP object header (must be last field)
/// }
/// ```
///
/// Parameters:
///   - class_name: PHP class name (supports namespaces with backslash, e.g., "MyExt\\Student")
///   - T: The Zig type to wrap (your data structure)
///
/// Optional T declarations:
///   - `init()`: Called after object allocation, before constructor.
///     Supported signatures: `fn(self: *T)` or `fn(self: *T, ce: *phpz.ClassEntry)`
///   - `deinit()`: Called during object destruction, before deallocation
///   - `register(fn) *phpz.ClassEntry`: Custom entry registration (e.g., to set parent class)
///
/// Example:
/// ```zig
/// const Student = extern struct {
///     name: [*]u8,
///     name_len: usize,
///     age: u8,
///
///     // Optional: Initialize default values
///     pub fn init(self: *Student) void {
///         self.age = 0;
///     }
///
///     // Optional: Initialize with class entry access
///     // pub fn init(self: *Student, ce: *phpz.ClassEntry) void { ... }
///
///     // Optional: Clean up resources
///     pub fn deinit(self: *Student) void {
///         // Free any allocated resources
///     }
///
///     // Optional: Custom registration (e.g., inherit from parent class)
///     pub fn register(impl: anytype) *phpz.ClassEntry {
///         return .from(impl(phpz.globals.class.entry("Stringable")));
///     }
///
///     pub fn construct(self: *Student, ctx: Ctx) !void {
///         var name: []u8 = undefined;
///         try ctx.call.parseArgs("s", .{ &name.ptr, &name.len });
///         self.name = name.ptr;
///         self.name_len = name.len;
///     }
///
///     pub fn getName(self: Student, ctx: Ctx) void {
///         ctx.ret.set(.string, self.name[0..self.name_len]);
///     }
///
///     pub fn setAge(self: *Student, ctx: Ctx) !void {
///         var age: i64 = undefined;
///         try ctx.call.parseArgs("l", .{&age});
///         self.age = @intCast(age);
///     }
/// };
///
/// // Create the PHP class wrapper
/// pub const StudentClass = phpz.Class("MyExt\\Student", Student);
///
/// // Register methods (typically in a comptime block)
/// comptime {
///     StudentClass.method("__construct", .construct);
///     StudentClass.method("getName", .getName);
///     StudentClass.method("setAge", .setAge);
/// }
///
/// // Register the class during module initialization
/// pub fn moduleStartup() !void {
///     StudentClass.register();
/// }
/// ```
pub fn Class(comptime class_name: [:0]const u8, comptime T: type) type {
    comptime {
        if (@typeInfo(T) != .@"struct" or @typeInfo(T).@"struct".layout != .@"extern")
            @compileError("Class type T must be an extern struct");
    }
    return extern struct {
        /// The wrapped Zig data structure
        impl: T,

        /// PHP object header (must be the last field for proper memory layout)
        std: c.zend_object,

        const Self = @This();

        /// The PHP class entry
        pub var entry: *zend.ClassEntry = undefined;

        /// Object handlers for this class (cloned from std_object_handlers)
        var handlers: c.zend_object_handlers = undefined;

        /// Object allocation and initialization callback for PHP.
        ///
        /// Called by PHP when creating a new instance: `new Student()`.
        /// This function:
        /// 1. Allocates memory for the object
        /// 2. Initializes the PHP object header
        /// 3. Calls T.init() if defined (supports `fn(self: *T)` or
        ///    `fn(self: *T, ce: *phpz.ClassEntry)`)
        /// 4. Sets up object handlers
        ///
        /// Note: This is an internal function called by PHP's object system.
        fn init(ce: ?*c.zend_class_entry) callconv(.c) ?*c.zend_object {
            var intern: *Self = @ptrCast(@alignCast(c.zend_object_alloc(@sizeOf(Self), ce.?)));
            c.zend_object_std_init(&intern.std, ce);
            c.object_properties_init(&intern.std, ce);
            if (@hasDecl(T, "init")) {
                if (comptime @typeInfo(@TypeOf(T.init)).@"fn".param_types.len == 1) {
                    intern.impl.init();
                } else {
                    comptime {
                        if (@typeInfo(@TypeOf(T.init)).@"fn".param_types.len != 2) @compileError("T.init must take 1 or 2 parameters");
                    }
                    intern.impl.init(entry);
                }
            }
            intern.std.handlers = &handlers;
            return &intern.std;
        }

        /// Object destruction callback for PHP.
        ///
        /// Called by PHP when the object is being destroyed (refcount reaches 0).
        /// This function:
        /// 1. Calls T.deinit() if defined (cleanup user resources)
        /// 2. Calls standard object destructor (cleanup PHP resources)
        ///
        /// Note: This is an internal function called by PHP's garbage collector.
        fn deinit(obj: ?*c.zend_object) callconv(.c) void {
            var intern: *Self = .from(.std, obj.?);
            if (@hasDecl(T, "deinit")) intern.impl.deinit();
            c.zend_object_std_dtor(obj);
        }

        /// Register this class with PHP.
        ///
        /// This function must be called during module initialization (in startup_fn)
        /// to make the class available to PHP code.
        ///
        /// Registration Modes (controlled by optional T declarations):
        ///
        /// 1. Default Mode (no special declarations):
        ///    - Calls auto-generated register_class_* function
        ///    - Framework sets up: create_object handler, object handlers, offset
        ///
        /// 2. Custom Entry Mode (T.register declared):
        ///    - `pub fn register(fn) *phpz.ClassEntry`
        ///    - Useful for setting parent class or implementing interfaces
        ///    - Framework still sets up handlers after your customization
        ///    Example: `return .from(impl(phpz.globals.class.entry("Stringable")));`
        ///
        /// The register_class_* function is generated from PHP stub files during
        /// the translate-c process and contains class metadata (methods, properties).
        ///
        /// Example:
        /// ```zig
        /// fn moduleStartup() !void {
        ///     StudentClass.register();
        ///     TeacherClass.register();
        /// }
        /// ```
        pub fn register() void {
            handlers = phpz.globals.global(.value, c.zend_object_handlers, "std_object_handlers");
            handlers.free_obj = &deinit;
            handlers.offset = @offsetOf(Self, "std");

            entry = callRegisterClassFn(class_name, T);
            c.phpz_class_entry_set_create_object(entry.ptr(), &init);
        }

        /// Apply custom object handlers.
        ///
        /// Only non-null fields override the current handler entries.
        /// Call from `T.register` — the class wrapper type is accessible in
        /// the same scope as the impl struct.
        ///
        /// Example:
        /// ```zig
        /// const User = extern struct {
        ///     pub fn register(impl: anytype) *phpz.ClassEntry {
        ///         Class.setObjectHandlers(.{ .clone_obj = &myClone });
        ///         return .from(impl(phpz.globals.class.entry("Stringable")));
        ///     }
        ///     fn myClone(self: *User) ?*c.zend_object {
        ///         // Custom clone implementation
        ///     }
        /// };
        /// pub const Class = phpz.Class("User", User);
        /// ```
        pub fn setObjectHandlers(comptime hs: ObjectHandlers) void {
            inline for (@typeInfo(ObjectHandlers).@"struct".field_names) |field_name| {
                const fv = @field(hs, field_name);
                if (fv != null) @field(handlers, field_name) = fv;
            }
        }

        /// Register a method for this PHP class.
        ///
        /// This function registers a Zig function as a method of the PHP class.
        /// It must be called at compile time before the class is registered.
        ///
        /// Parameters:
        ///   - func_name: PHP method name (null-terminated, e.g., "__construct", "getName")
        ///   - func_decl: Enum value corresponding to the T's method declaration
        ///
        /// Special method names:
        ///   - "__construct": Constructor, called when `new ClassName()` is executed
        ///   - "__destruct": Destructor, called before object destruction
        ///   - "__toString": String conversion, called when object is cast to string
        ///   - "__get", "__set": Property accessors for dynamic properties
        ///   - Other PHP magic methods are supported
        ///
        /// Supported method signatures (T is the impl type):
        ///   Object methods — first parameter is self (T, *T, or *const T):
        ///   - `fn (T|*T|*const T, Ctx) void|!void`
        ///   - `fn (T|*T|*const T) void|!void`
        ///   Static methods — first parameter is not self:
        ///   - `fn (Ctx) void|!void`
        ///   - `fn () void|!void`
        ///
        /// Example:
        /// ```zig
        /// const Student = extern struct {
        ///     name: []const u8,
        ///     age: u8,
        ///
        ///     pub fn construct(self: *Student, ctx: Ctx) !void {
        ///         var name: []u8 = undefined;
        ///         try ctx.call.parseArgs("s", .{ &name.ptr, &name.len });
        ///         self.name = name;
        ///     }
        ///
        ///     pub fn getName(self: Student, ctx: Ctx) void {
        ///         ctx.ret.set(.string, self.name);
        ///     }
        ///
        ///     pub fn setAge(self: *Student, ctx: Ctx) !void {
        ///         var age: i64 = undefined;
        ///         try ctx.call.parseArgs("l", .{&age});
        ///         self.age = @intCast(age);
        ///     }
        /// };
        ///
        /// pub const StudentClass = phpz.Class("Student", Student);
        ///
        /// comptime {
        ///     StudentClass.method("__construct", .construct);
        ///     StudentClass.method("getName", .getName);
        ///     StudentClass.method("setAge", .setAge);
        /// }
        /// ```
        pub fn method(comptime func_name: [:0]const u8, comptime func_decl: std.meta.DeclEnum(T)) void {
            function_helper.methodWithClass(Self, class_name, func_name, @field(T, @tagName(func_decl)));
        }

        /// Increments the reference count of the object.
        pub inline fn addref(self: *Self) void {
            zend.Object.addref(.from(&self.std));
        }

        /// Decrements the reference count of the object.
        pub inline fn delref(self: *Self) void {
            zend.Object.delref(.from(&self.std));
        }

        /// Release the object (decrement refcount, destroy if zero).
        pub inline fn release(self: *Self) void {
            zend.Object.release(.from(&self.std));
        }

        /// Retrieves the parent struct pointer from a field pointer.
        pub fn from(comptime field: std.meta.FieldEnum(Self), field_ptr: *@FieldType(Self, @tagName(field))) *Self {
            return @fieldParentPtr(
                @tagName(field),
                @as(
                    *align(@alignOf(Self)) @FieldType(Self, @tagName(field)),
                    @alignCast(field_ptr),
                ),
            );
        }

        /// Creates an instance of the class from a Zval.Object.
        pub fn fromObjectZval(zv: *Zval.Object) *Self {
            return .from(.std, zv.object().ptr());
        }

        /// Creates an instance of the class without calling its constructor.
        ///
        /// Ownership: caller owns the returned object reference; call
        /// `release()` unless the object is transferred into a zval/PHP return.
        ///
        /// Must be called after `register()`, otherwise `entry` is undefined.
        pub fn create() *Self {
            // emalloc never returns null (it aborts on OOM), so `orelse` is unreachable.
            return .from(.std, init(entry.ptr()) orelse unreachable);
        }

        /// Calls a method on the object.
        /// retval is optional, if not provided the return value will be discarded.
        ///
        /// Returns `error.MethodNotFound` if the method is not in the class.
        /// Returns `error.PhpException` if the called method throws a PHP exception.
        pub fn call(self: *Self, method_name: []const u8, retval: ?*c.zval, params: anytype) zend.Object.CallError!void {
            const obj: *zend.Object = .from(&self.std);
            try obj.call(method_name, retval, params);
        }

        /// Calls a method on the object and converts a Zend bailout into `error.ZendBailout`.
        pub fn tryCall(self: *Self, method_name: []const u8, retval: ?*c.zval, params: anytype) zend.Object.TryCallError!void {
            const obj: *zend.Object = .from(&self.std);
            try obj.tryCall(method_name, retval, params);
        }

        pub const ConstructError = zend.Object.ConstructorError || zend.Function.Error;
        pub const TryConstructError = zend.Object.ConstructorError || zend.Function.TryCallError;

        /// Calls the constructor (`__construct`) with the given parameters.
        /// Does nothing if the class has no constructor defined.
        ///
        /// Returns `error.AccessDenied` if the constructor is inaccessible.
        /// Returns `error.PhpException` if the constructor throws a PHP exception.
        pub fn construct(self: *Self, params: anytype) ConstructError!void {
            const obj: *zend.Object = .from(&self.std);
            if (try obj.constructor()) |ctor| try ctor.callMethod(obj, null, params);
        }

        /// Calls the constructor and converts a Zend bailout into `error.ZendBailout`.
        pub fn tryConstruct(self: *Self, params: anytype) TryConstructError!void {
            const obj: *zend.Object = .from(&self.std);
            if (try obj.constructor()) |ctor| try ctor.tryCallMethod(obj, null, params);
        }

        /// Create a new instance and call its constructor in one step.
        ///
        /// Combines `create()` and `construct()`. If the class has no constructor,
        /// the params are silently ignored.
        ///
        /// Must be called after `register()`, otherwise `entry` is undefined.
        ///
        /// Ownership: caller owns the returned object reference; call
        /// `release()` unless the object is transferred into a zval/PHP return.
        ///
        /// Returns `error.AccessDenied` if the constructor is inaccessible.
        /// Returns `error.PhpException` if the constructor throws a PHP exception.
        pub fn new(params: anytype) ConstructError!*Self {
            const instance = create();
            errdefer instance.release();
            try instance.construct(params);
            return instance;
        }

        /// Create a new instance, call its constructor, and convert a Zend bailout into `error.ZendBailout`.
        pub fn tryNew(params: anytype) TryConstructError!*Self {
            const instance = create();
            errdefer instance.release();
            try instance.tryConstruct(params);
            return instance;
        }

        /// Update object property value.
        ///
        /// Returns `error.PhpException` if a magic `__set` handler throws.
        pub fn updateProperty(self: *Self, comptime zk: Zval.Kind, prop_name: []const u8, prop_value: Zval.Type(zk)) zend.Function.Error!void {
            const ce = entry.ptr();
            switch (zk) {
                .null => c.zend_update_property_null(ce, &self.std, prop_name.ptr, prop_name.len),
                .bool => c.zend_update_property_bool(ce, &self.std, prop_name.ptr, prop_name.len, if (prop_value) 1 else 0),
                .int => c.zend_update_property_long(ce, &self.std, prop_name.ptr, prop_name.len, prop_value),
                .float => c.zend_update_property_double(ce, &self.std, prop_name.ptr, prop_name.len, prop_value),
                .string => c.zend_update_property_stringl(ce, &self.std, prop_name.ptr, prop_name.len, prop_value.ptr, prop_value.len),
                .undef, .indirect, .ptr => @compileError("'" ++ @tagName(zk) ++ "' cannot be set as object property"),
                inline else => {
                    var zv: c.zval = undefined;
                    native.set(&zv, zk, prop_value);
                    c.zend_update_property(ce, &self.std, prop_name.ptr, prop_name.len, &zv);
                },
            }
            if (phpz.errors.hasException()) return zend.Function.Error.PhpException;
        }

        /// Read object property.
        ///
        /// Ownership: returned pointer is either borrowed from the object/runtime
        /// or points at caller-provided scratch. Never dtor the returned pointer
        /// directly; use `Zval.native.tryDtor(scratch)` for scratch cleanup.
        ///
        /// Returns `error.PhpException` if a magic `__get` handler throws.
        ///
        /// Initialize `scratch` to IS_UNDEF before calling. If `scratch` is no
        /// longer IS_UNDEF after the call, destroy it when done.
        pub fn property(self: *Self, prop_name: []const u8, silent: bool, scratch: *c.zval) zend.Function.Error!*Zval {
            const val = c.zend_read_property(entry.ptr(), &self.std, prop_name.ptr, prop_name.len, silent, scratch);
            if (phpz.errors.hasException()) return zend.Function.Error.PhpException;
            return .from(val);
        }

        /// Unset (delete) object property.
        ///
        /// Returns `error.PhpException` if a magic `__unset` handler throws.
        pub fn unsetProperty(self: *Self, prop_name: []const u8) zend.Function.Error!void {
            c.zend_unset_property(entry.ptr(), &self.std, prop_name.ptr, prop_name.len);
            if (phpz.errors.hasException()) return zend.Function.Error.PhpException;
        }
    };
}

/// Create a simple PHP class without Zig data binding.
///
/// This function creates a lightweight PHP class wrapper for class and method
/// registration. Unlike `Class`, it does not manage object lifecycle or bind
/// Zig data structures. The internal implementation is handled by PHP's native
/// object system.
///
/// Use cases:
///   - Exception subclasses (e.g., custom exceptions extending RuntimeException)
///   - Interfaces (e.g., Tester extends Stringable)
///   - PHP traits (e.g., `SimpleClass("MyExt\\LoggerTrait", void)`)
///   - PHP enums (e.g., `SimpleClass("MyExt\\Status", void)`). Use `zend.ClassEntry.isEnum()`
///     for enum checking, and `zend.Object.enumCaseName()`, `zend.Object.enumCaseValue()` for case inspection.
///   - Classes where internal implementation is handled by PHP runtime
///
/// Parameters:
///   - class_name: PHP class name (supports namespaces with backslash)
///   - T: A type with optional `register` declaration for custom registration
///
/// Optional T declarations:
///   - `register(fn) *ClassEntry`: Custom registration (e.g., to set parent class)
///
/// Example:
/// ```zig
/// // Create a custom exception class
/// pub const MyException = phpz.SimpleClass("MyExt\\MyException", struct {
///     pub fn register(impl: anytype) *phpz.ClassEntry {
///         return .from(impl(phpz.globals.class.entry("RuntimeException")));
///     }
/// });
///
/// // Throw the exception
/// pub fn throw(message: [:0]const u8) void {
///     _ = phpz.errors.throwException(MyException.entry, message, 0);
/// }
///
/// // Register during module initialization
/// pub fn moduleStartup() !void {
///     MyException.register();
/// }
/// ```
pub fn SimpleClass(comptime class_name: [:0]const u8, comptime T: type) type {
    return struct {
        /// The PHP class entry
        pub var entry: *zend.ClassEntry = undefined;

        pub fn register() void {
            entry = callRegisterClassFn(class_name, T);
        }

        pub fn method(comptime func_name: [:0]const u8, comptime func: anytype) void {
            function_helper.method(class_name, func_name, func);
        }
    };
}

/// Generates the register_class_* function name from a PHP class name.
///
/// This function converts a PHP class name (which may contain backslashes for
/// namespaces) into the corresponding C function name generated by PHP's
/// gen_stub.php tool.
///
/// Example:
///   "MyExt\\Student" -> "register_class_MyExt_Student"
///
/// The function also validates that the generated function exists in the
/// translated C headers, providing a helpful error message if not found.
fn getRegisterClassFnName(comptime class_name: [:0]const u8) [:0]const u8 {
    comptime var buffer: [class_name.len:0]u8 = undefined;
    for (class_name, 0..) |ch, i| buffer[i] = if (ch == '\\') '_' else ch;
    const result = "register_class_" ++ &buffer;

    if (!@hasDecl(c, result)) {
        @compileError(
            \\ class register function not found:
        ++ result ++
            \\
            \\ You need to generate arginfo header file and include it in your C code:
            \\ 1. Generate the arginfo header: php build/gen_stub.php your_extension.stub.php
            \\ 2. Include in your extension: #include "your_extension_arginfo.h"
        );
    }

    return result;
}

fn callRegisterClassFn(comptime class_name: [:0]const u8, comptime T: type) *phpz.ClassEntry {
    const register_class_fn = @field(c, getRegisterClassFnName(class_name));
    return switch (T) {
        void => .from(@call(.auto, register_class_fn, .{})),
        else => if (@hasDecl(T, "register"))
            @call(.auto, T.register, .{register_class_fn})
        else
            .from(@call(.auto, register_class_fn, .{})),
    };
}
