const std = @import("std");

const c = @import("root.zig").c;
const function_helper = @import("function.zig");

/// Type alias for Zend class entry structure.
/// Represents a PHP class definition in the Zend engine.
pub const ClassEntry = c.zend_class_entry;

/// Create a PHP class wrapper around a Zig type.
///
/// This function generates a wrapper structure that bridges Zig code with PHP's
/// object system. The wrapper handles object lifecycle (allocation, initialization,
/// destruction) and provides methods for registering the class and its methods.
///
/// The generated wrapper structure layout:
/// ```
/// extern struct {
///     inner: T,              // Your Zig data structure
///     std: zend_object,      // PHP object header (must be last field)
/// }
/// ```
///
/// Parameters:
///   - class_name: PHP class name (supports namespaces with backslash, e.g., "MyExt\\Student")
///   - T: The Zig type to wrap (your data structure)
///
/// Optional T declarations:
///   - `init()`: Called after object allocation, before constructor
///   - `deinit()`: Called during object destruction, before deallocation
///   - `register(fn) *ClassEntry`: Custom class registration (e.g., to set parent class)
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
///     // Optional: Clean up resources
///     pub fn deinit(self: *Student) void {
///         // Free any allocated resources
///     }
///
///     // Optional: Custom registration (e.g., inherit from parent class)
///     pub fn register(impl: anytype) *ClassEntry {
///         return impl(c.zend_ce_stringable); // Implement Stringable
///     }
///
///     pub fn construct(self: *Student, ctx: *ExecContext) !void {
///         var name: []u8 = undefined;
///         try ctx.parse("s", .{ &name.ptr, &name.len });
///         self.name = name.ptr;
///         self.name_len = name.len;
///     }
///
///     pub fn getName(self: Student, ret: *Zval) void {
///         ret.set(.string, self.name[0..self.name_len]);
///     }
///
///     pub fn setAge(self: *Student, ctx: *ExecContext) !void {
///         var age: i64 = undefined;
///         try ctx.parse("l", .{&age});
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
    return extern struct {
        /// The wrapped Zig data structure
        inner: T,

        /// PHP object header (must be the last field for proper memory layout)
        std: c.zend_object,

        const Self = @This();

        /// The PHP class name
        pub const name = class_name;

        /// The PHP class entry
        pub var entry: *ClassEntry = undefined;

        /// Object handlers for this class (cloned from std_object_handlers)
        var handlers: c.zend_object_handlers = undefined;

        /// Object allocation and initialization callback for PHP.
        ///
        /// Called by PHP when creating a new instance: `new Student()`.
        /// This function:
        /// 1. Allocates memory for the object
        /// 2. Initializes the PHP object header
        /// 3. Calls T.init() if defined
        /// 4. Sets up object handlers
        ///
        /// Note: This is an internal function called by PHP's object system.
        pub fn init(ce: ?*ClassEntry) callconv(.c) ?*c.zend_object {
            var intern: *Self = @ptrCast(@alignCast(c.zend_object_alloc(@sizeOf(Self), ce.?)));
            c.zend_object_std_init(&intern.std, ce);
            c.object_properties_init(&intern.std, ce);
            if (@hasDecl(T, "init")) intern.inner.init();
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
        pub fn deinit(obj: ?*c.zend_object) callconv(.c) void {
            var intern: *Self = @fieldParentPtr("std", obj.?);
            if (@hasDecl(T, "deinit")) intern.inner.deinit();
            c.zend_object_std_dtor(obj);
        }

        /// Register this class with PHP.
        ///
        /// This function must be called during module initialization (in startup_fn)
        /// to make the class available to PHP code. It:
        /// 1. Calls the auto-generated register_class_* function from translate-c
        /// 2. Sets up object creation handler (init)
        /// 3. Configures object handlers (deinit, offset)
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
            const register_class_fn_name = comptime blk: {
                var buffer: [class_name.len]u8 = undefined;
                for (class_name, 0..) |ch, i| {
                    buffer[i] = if (ch == '\\') '_' else ch;
                }
                const replaced = &buffer;
                const result = std.fmt.comptimePrint("register_class_{s}", .{replaced});

                if (!@hasDecl(c, result)) {
                    @compileError(
                        \\ class register function not found:
                    ++ result ++
                        \\
                        \\ You need to generate arginfo header file and include it in your C code:
                        \\ 1. Generate the arginfo header: php gen_stub.php your_extension.stub.php
                        \\ 2. Include in your extension: #include "your_extension_arginfo.h"
                    );
                }

                break :blk result;
            };

            entry = if (@hasDecl(T, "register"))
                @call(.auto, T.register, .{@field(c, register_class_fn_name)})
            else
                @call(.auto, @field(c, register_class_fn_name), .{});

            // FIXME: unnamed_1 ...
            entry.unnamed_1.create_object = &init;
            handlers = c.std_object_handlers;
            handlers.free_obj = &deinit;
            handlers.offset = @offsetOf(Self, "std");
        }

        /// Register a method for this PHP class.
        ///
        /// This function registers a Zig function as a method of the PHP class.
        /// It must be called at compile time before the class is registered.
        ///
        /// Parameters:
        ///   - func_name: PHP method name (null-terminated, e.g., "__construct", "getName")
        ///   - func: Enum value corresponding to the T's method declaration
        ///
        /// Special method names:
        ///   - "__construct": Constructor, called when `new ClassName()` is executed
        ///   - "__destruct": Destructor, called before object destruction
        ///   - "__toString": String conversion, called when object is cast to string
        ///   - "__get", "__set": Property accessors for dynamic properties
        ///   - Other PHP magic methods are supported
        ///
        /// Method signatures follow the same rules as phpz.method():
        ///   - `fn (self: T, ctx: *ExecContext, ret: *Zval) !void`
        ///   - `fn (self: *T, ctx: *ExecContext) !void`
        ///   - `fn (self: T, ret: *Zval) !void`
        ///   - `fn (self: T) !ReturnType`
        ///
        /// Example:
        /// ```zig
        /// const Student = extern struct {
        ///     name: []const u8,
        ///     age: u8,
        ///
        ///     pub fn construct(self: *Student, ctx: *ExecContext) !void {
        ///         var name: []u8 = undefined;
        ///         try ctx.parse("s", .{ &name.ptr, &name.len });
        ///         self.name = name;
        ///     }
        ///
        ///     pub fn getName(self: Student, ret: *Zval) void {
        ///         ret.set(.string, self.name);
        ///     }
        ///
        ///     pub fn setAge(self: *Student, ctx: *ExecContext) !void {
        ///         var age: i64 = undefined;
        ///         try ctx.parse("l", .{&age});
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
        pub fn method(comptime func_name: [:0]const u8, comptime func: std.meta.DeclEnum(T)) void {
            function_helper.method(Self, func_name, @field(T, @tagName(func)));
        }
    };
}
