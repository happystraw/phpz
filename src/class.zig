//! PHP class declaration, method binding, and optional Zig object storage.

const std = @import("std");

const abi = @import("abi.zig");
const c = @import("c.zig").c;
const Ctx = @import("Ctx.zig");
const errors = @import("errors.zig");
const function_helper = @import("function.zig");
const globals = @import("globals.zig");
const stub = @import("stub.zig");
const zend = @import("zend.zig");

const Layout = enum { std, backed };
const MethodHandler = function_helper.Handler;
const MethodKind = enum { instance, static };
const Method = struct { name: [:0]const u8, kind: MethodKind };
const MethodMap = std.StaticStringMap(Method);
const BindingStrategy = enum { automatic, explicit };
fn Resolved(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Zend's standard layout or a class carrying Zig backing data.
        layout: Layout,
        /// Stub methods that require Zig bindings.
        required_methods: MethodMap,
        /// Whether methods are discovered from `T` or supplied explicitly.
        binding_strategy: BindingStrategy,
        /// Fallible adapter around the stub-generated class registration.
        register: fn () anyerror!*zend.ClassEntry,
        /// Optional initializer for the Zig backing value.
        init: ?fn () anyerror!T,
        /// Optional destructor for the Zig backing value.
        deinit: ?fn (*T) void,
        /// Optional cloner for the Zig backing value.
        clone: ?fn (*const T) anyerror!T,
        /// Zend object handler overrides.
        handlers: ObjectHandlers,

        fn resolve(comptime class_name: [:0]const u8, comptime options: anytype) Self {
            const info = @typeInfo(@TypeOf(options));
            if (info != .@"struct" or (info.@"struct".is_tuple and info.@"struct".field_names.len != 0)) {
                @compileError("Class " ++ class_name ++ " options must be a named struct literal");
            }

            const layout: Layout = if (T == void)
                .std
            else switch (@typeInfo(T)) {
                .@"struct" => |struct_info| if (struct_info.field_types.len == 0) .std else .backed,
                else => @compileError("Class T must be void or a struct"),
            };

            inline for (info.@"struct".field_names) |field_name| {
                const common = std.mem.eql(u8, field_name, "methods") or std.mem.eql(u8, field_name, "register");
                const backing = std.mem.eql(u8, field_name, "init") or
                    std.mem.eql(u8, field_name, "deinit") or
                    std.mem.eql(u8, field_name, "clone") or
                    std.mem.eql(u8, field_name, "handlers");
                if (!common and !backing) {
                    @compileError("Class " ++ class_name ++ " has unknown option '." ++ field_name ++ "'");
                }
                if (layout == .std and backing) {
                    @compileError("Class " ++ class_name ++ " option '." ++ field_name ++ "' requires Zig backing data");
                }
            }

            const required_methods = blk: {
                const table_name = stub.classMethodsSymbolName(class_name);
                if (!@hasDecl(c, table_name)) break :blk MethodMap.initComptime(.{});

                const table = @field(c, table_name);
                const Pair = struct { []const u8, Method };
                const symbol_prefix = stub.methodSymbolPrefix(class_name);
                var pairs: [table.len]Pair = undefined;
                var len: usize = 0;

                for (table) |fe| {
                    const method = zend.FunctionEntry.from(&fe);
                    if (method.handler() == null) continue;

                    const name = method.name() orelse continue;
                    const own_symbol = symbol_prefix ++ name;
                    if (!@hasDecl(c, own_symbol)) continue;

                    pairs[len] = .{
                        name,
                        .{ .name = name, .kind = if (method.isStatic()) .static else .instance },
                    };
                    len += 1;
                }

                break :blk MethodMap.initComptime(pairs[0..len]);
            };

            const binding_strategy: BindingStrategy = if (!@hasField(@TypeOf(options), "methods"))
                .automatic
            else switch (@typeInfo(@TypeOf(options.methods))) {
                .enum_literal => if (options.methods == .automatic)
                    .automatic
                else
                    @compileError("Class " ++ class_name ++ " .methods must be .automatic or named bindings such as .{ .increment = Counter.increment }"),
                .@"struct" => |methods_info| if (!methods_info.is_tuple or methods_info.field_names.len == 0)
                    .explicit
                else
                    @compileError("Class " ++ class_name ++ " .methods must use named fields, not tuple entries; use .{ .increment = Counter.increment }"),
                else => @compileError("Class " ++ class_name ++ " .methods has unsupported Zig type '" ++ @typeName(@TypeOf(options.methods)) ++ "'; expected .automatic or a struct of named method bindings"),
            };

            const register: fn () anyerror!*zend.ClassEntry = blk: {
                const fn_name = stub.classRegisterFnSymbolName(class_name);
                if (!@hasDecl(c, fn_name)) {
                    @compileError(
                        \\ class register function not found:
                    ++ fn_name ++
                        \\
                        \\ Class entry generation must be enabled in your stub file.
                        \\ 1. Add @generate-class-entries to the file-level docblock:
                        \\    /**
                        \\     * @generate-class-entries
                        \\     */
                        \\ 2. Regenerate the arginfo header: php build/gen_stub.php your_extension.stub.php
                        \\ 3. Include the generated header in your C code: #include "your_extension_arginfo.h"
                    );
                }

                const c_register_fn = @field(c, fn_name);
                const Args = std.meta.ArgsTuple(@TypeOf(c_register_fn));
                if (@hasField(@TypeOf(options), "register")) {
                    break :blk struct {
                        fn typed(args: Args) *zend.ClassEntry {
                            return .from(@call(.always_inline, c_register_fn, args));
                        }

                        fn call() anyerror!*zend.ClassEntry {
                            return @call(.auto, options.register, .{typed});
                        }
                    }.call;
                }

                if (@typeInfo(Args).@"struct".field_types.len != 0) {
                    @compileError("Class " ++ class_name ++ " requires a .register hook");
                }
                break :blk struct {
                    fn call() anyerror!*zend.ClassEntry {
                        return .from(@call(.always_inline, c_register_fn, .{}));
                    }
                }.call;
            };

            var initializer: ?fn () anyerror!T = null;
            var deinitializer: ?fn (*T) void = null;
            var cloner: ?fn (*const T) anyerror!T = null;
            var handlers: ObjectHandlers = .{};

            if (layout == .backed) {
                if (@hasField(@TypeOf(options), "init")) {
                    initializer = switch (@typeInfo(@TypeOf(options.init))) {
                        .enum_literal => if (options.init == .none)
                            null
                        else if (options.init == .default) blk: {
                            break :blk struct {
                                fn call() anyerror!T {
                                    return .{};
                                }
                            }.call;
                        } else @compileError("Class " ++ class_name ++ " .init must be .none, .default, or a function"),
                        .@"fn" => blk: {
                            break :blk struct {
                                fn call() anyerror!T {
                                    return @call(.auto, options.init, .{});
                                }
                            }.call;
                        },
                        else => @compileError("Class " ++ class_name ++ " .init must be .none, .default, or a function"),
                    };
                }

                if (@hasField(@TypeOf(options), "deinit")) {
                    deinitializer = options.deinit;
                }

                if (@hasField(@TypeOf(options), "clone")) {
                    cloner = struct {
                        fn call(value: *const T) anyerror!T {
                            return @call(.auto, options.clone, .{value});
                        }
                    }.call;
                }

                if (@hasField(@TypeOf(options), "handlers")) {
                    handlers = options.handlers;
                }
            }

            return .{
                .layout = layout,
                .required_methods = required_methods,
                .binding_strategy = binding_strategy,
                .register = register,
                .init = initializer,
                .deinit = deinitializer,
                .clone = cloner,
                .handlers = handlers,
            };
        }
    };
}

/// PHP object handler overrides.
///
/// Define a `phpz.ObjectHandlers` with the handlers you want to replace and
/// pass it through the Class `.handlers` option. Only non-null fields replace
/// entries cloned from `std_object_handlers`.
///
/// Example:
/// ```zig
/// const StudentClass = phpz.Class("Student", Student, .{
///     .handlers = phpz.ObjectHandlers{ .read_dimension = &readDimension },
/// });
/// ```
pub const ObjectHandlers = struct {
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

/// Build the Zig wrapper for a PHP class generated by `gen_stub.php`.
///
/// `class_name` is the exact fully-qualified PHP class name. It selects the
/// generated registration function and method table. `Class` validates method
/// bindings and exports their `zim_*` handlers at compile time. The returned
/// type is registered later, normally by adding it to `phpz.module`'s
/// `.classes` list.
///
/// ## Object layout
///
/// `T` controls the object layout:
/// - `void` or a zero-field struct uses Zend's standard object layout.
/// - A non-empty struct adds an optional Zig `T` backing value to every object.
///
/// ## Method binding
///
/// Method binding defaults to `.automatic`. Every public function declared by
/// `T` must have the exact name of a concrete stub method, and every concrete
/// stub method must be implemented. Explicit stub aliases are skipped. A named
/// `.methods` struct provides an exact mapping instead.
///
/// In automatic mode, every `pub fn` in `T` is treated as a PHP method.
/// Functions used by `.register`, `.init`, `.deinit`, or `.clone` must remain
/// private; declaring them `pub` would also make automatic binding treat them
/// as PHP methods and match them against the stub.
///
/// ## Examples
///
/// ```zig
/// // Non-empty Counter gives each PHP object Zig backing. Public methods are
/// // discovered automatically.
/// const CounterClass = phpz.Class("Vendor\\Counter", Counter, .{});
///
/// // Explicit bindings can map PHP names to differently named Zig functions.
/// const ClockClass = phpz.Class("Vendor\\Clock", Clock, .{
///     .methods = .{
///         .@"__construct" = Clock.create,
///         .time = Clock.current,
///     },
/// });
///
/// // void keeps all state in Zend properties and requires explicit bindings.
/// const TagClass = phpz.Class("Vendor\\Tag", void, .{
///     .methods = .{
///         .@"__construct" = constructTag,
///         .name = tagName,
///     },
/// });
/// ```
///
/// `.register` is available for either object layout. Backed classes additionally
/// support lifecycle options, which can be combined with registration:
///
/// ```zig
/// fn registerCollection(comptime register_fn: anytype) *phpz.ClassEntry {
///     return register_fn(.{ParentClass.entry.ptr()});
/// }
///
/// const CollectionClass = phpz.Class("Vendor\\Collection", Collection, .{
///     .register = registerCollection,
///     .init = .default,
///     .deinit = Collection.deinit,
///     .clone = Collection.clone,
/// });
/// ```
///
/// A parent class or interface referenced through `.entry` must appear before
/// the dependent class in `phpz.module`'s `.classes` list.
///
/// ## Method signatures
///
/// - Standard-layout methods and backed static methods use `fn () void` or
///   `fn (Ctx) void`, optionally error-returning.
/// - Backed instance methods receive `*T` or `*const T`, optionally followed by
///   `Ctx`, and return `void` or `!void`.
/// - A backed `__construct` accepts no arguments or one `Ctx` and returns `T`
///   or `!T`. The result initializes the backing while PHP observes `void`.
///
/// ## Options
///
/// - `.methods`: omit or use `.automatic` for exact declaration discovery, or
///   provide a named struct for explicit bindings.
/// - `.register`: receives the typed stub-generated registration function,
///   supplies its parent class or interfaces, and returns `*ClassEntry` or an
///   error union containing it.
/// - `.init`: omit or use `.none` to leave backing empty, `.default` to create
///   it with `.{}`, or provide a function returning `T` or `!T`.
/// - `.deinit`: releases an initialized backing with `fn (*T) void`.
/// - `.clone`: copies backing with `fn (*const T) T` or `fn (*const T) !T`.
/// - `.handlers`: overrides selected Zend handlers with `ObjectHandlers`.
///
/// Backing options (`.init`, `.deinit`, `.clone`, and `.handlers`) require a
/// non-empty `T`. Before backing is initialized, instance methods throw a PHP
/// error directing the caller to the constructor.
pub fn Class(comptime class_name: [:0]const u8, comptime T: type, comptime options: anytype) type {
    const resolved_options: Resolved(T) = .resolve(class_name, options);
    return switch (resolved_options.layout) {
        .std => StdClass(class_name, T, options, resolved_options),
        .backed => BackedClass(class_name, T, options, resolved_options),
    };
}

/// Create a wrapper for a stub-generated class, interface, trait, or enum
/// without Zig backing data.
///
/// This is a shorthand for `Class(name, void, options)`.
pub fn ClassDecl(comptime class_name: [:0]const u8, comptime options: anytype) type {
    return Class(class_name, void, options);
}

fn StdClass(comptime class_name: [:0]const u8, comptime T: type, comptime options: anytype, comptime resolved: Resolved(T)) type {
    return struct {
        const Self = @This();

        /// The registered PHP class entry. Valid after `register()` succeeds.
        pub var entry: *zend.ClassEntry = undefined;

        comptime {
            bindMethods(class_name, T, Self, options, resolved);
        }

        /// Register this class with PHP during module initialization.
        ///
        /// The stub-generated `register_class_*` function creates the class
        /// entry. A custom `.register` option can supply its parent or
        /// implemented interfaces; errors from that hook are propagated.
        pub fn register() !void {
            entry = try resolved.register();
        }
    };
}

fn BackedClass(comptime class_name: [:0]const u8, comptime T: type, comptime options: anytype, comptime resolved: Resolved(T)) type {
    comptime {
        if (@alignOf(?T) > c.ZEND_MM_ALIGNMENT) {
            @compileError("optional Zig object data alignment exceeds Zend MM alignment");
        }
    }

    return extern struct {
        /// Aligned storage for the optional Zig backing.
        storage: [@sizeOf(?T)]u8 align(@alignOf(?T)),

        /// PHP object header. It must remain the final physical field.
        std: c.zend_object,

        const Self = @This();

        /// The registered PHP class entry. Valid after `register()` succeeds.
        pub var entry: *zend.ClassEntry = undefined;

        /// Object handlers for this class, cloned from `std_object_handlers`.
        var handlers: c.zend_object_handlers = undefined;

        comptime {
            bindMethods(class_name, T, Self, options, resolved);
        }

        /// Register this class and install its Zig object lifecycle with PHP.
        ///
        /// The function clones standard handlers, applies configured lifecycle
        /// and handler overrides, creates the class entry, then installs
        /// `create_object`. Errors from a custom `.register` hook are propagated.
        pub fn register() !void {
            handlers = globals.global(.value, c.zend_object_handlers, "std_object_handlers");
            handlers.free_obj = lifecycle.destroyObject;
            handlers.offset = @offsetOf(Self, "std");
            handlers.clone_obj = if (resolved.clone != null) lifecycle.cloneObject else null;

            // Apply object handlers
            inline for (@typeInfo(ObjectHandlers).@"struct".field_names) |field_name| {
                const value = @field(resolved.handlers, field_name);
                if (value != null) @field(handlers, field_name) = value;
            }

            entry = try resolved.register();
            c.phpz_class_entry_set_create_object(entry.ptr(), lifecycle.createObject);
        }

        const lifecycle = struct {
            fn createObject(ce: ?*c.zend_class_entry) callconv(.c) ?*c.zend_object {
                const intern = alloc(ce.?);
                intern.initBacking();
                return &intern.std;
            }

            fn destroyObject(obj: ?*c.zend_object) callconv(.c) void {
                const self: *Self = .fromStd(obj.?);
                self.clearBacking();
                c.zend_object_std_dtor(obj);
            }

            fn cloneObject(obj: ?*c.zend_object) callconv(.c) ?*c.zend_object {
                const source: *Self = .fromStd(obj.?);
                const target = alloc(obj.?.ce.?);
                const source_backing: *const T = source.backing() orelse {
                    errors.throwError(null, "Cannot clone uninitialized " ++ class_name, .{});
                    return &target.std;
                };
                const cloner = resolved.clone orelse unreachable;
                const cloned = cloner(source_backing) catch |err| {
                    if (err == error.ZendBailout or err == error.OutOfMemory) zend.bailout.raise();
                    if (!errors.hasException()) {
                        errors.throwError(null, "%s while cloning " ++ class_name, .{@errorName(err).ptr});
                    }
                    return &target.std;
                };
                target.backingStorage().* = cloned;
                c.zend_objects_clone_members(&target.std, &source.std);
                return &target.std;
            }

            fn alloc(ce: *c.zend_class_entry) *Self {
                const intern: *Self = @ptrCast(@alignCast(c.zend_object_alloc(@sizeOf(Self), ce).?));
                c.zend_object_std_init(&intern.std, ce);
                c.object_properties_init(&intern.std, ce);
                intern.std.handlers = &handlers;
                intern.backingStorage().* = null;
                return intern;
            }
        };

        fn initBacking(self: *Self) void {
            if (resolved.init) |initializer| {
                self.backingStorage().* = initializer() catch |err| {
                    if (err == error.ZendBailout or err == error.OutOfMemory) zend.bailout.raise();
                    if (!errors.hasException()) {
                        errors.throwError(null, "%s while initializing " ++ class_name, .{@errorName(err).ptr});
                    }
                    return;
                };
            }
        }

        fn clearBacking(self: *Self) void {
            if (self.backingStorage().*) |*value| {
                if (resolved.deinit) |deinitializer| deinitializer(value);
                self.backingStorage().* = null;
            }
        }

        fn commitBacking(self: *Self, value: T) void {
            self.clearBacking();
            self.backingStorage().* = value;
        }

        fn receiver(ctx: *Ctx) ?*Self {
            const obj = ctx.call.this() orelse {
                errors.throwError(null, class_name ++ " must be called on an object", .{});
                return null;
            };
            if (obj.ptr().handlers != &handlers or !obj.instanceof(entry)) {
                errors.throwError(null, "invalid object layout for " ++ class_name, .{});
                return null;
            }
            return .fromStd(obj.ptr());
        }

        inline fn backingStorage(self: *Self) *?T {
            return @ptrCast(@alignCast(&self.storage));
        }

        /// Returns the mutable Zig backing value, or null before it is initialized.
        ///
        /// The returned pointer is borrowed from this PHP object and does not
        /// change its ownership or reference count.
        pub fn backing(self: *Self) ?*T {
            return if (self.backingStorage().*) |*value| value else null;
        }

        /// Returns the underlying Zend object without changing ownership.
        pub fn object(self: *Self) *zend.Object {
            return .from(&self.std);
        }

        /// Recover this wrapper from its trailing Zend object header.
        ///
        /// This conversion is unchecked. `obj` must point to the `std` field of
        /// an object created with this exact `Self` layout.
        pub fn fromStd(obj: *c.zend_object) *Self {
            return @fieldParentPtr("std", obj);
        }

        /// Creates an instance without calling its PHP constructor.
        ///
        /// The configured `.init` initializer is still applied to its backing.
        ///
        /// Ownership: caller owns the returned object reference; call
        /// `object().release()` unless ownership is transferred to PHP or a zval.
        /// `register()` must have succeeded before calling this function.
        pub fn create() *Self {
            const intern = lifecycle.alloc(entry.ptr());
            intern.initBacking();
            return intern;
        }

        /// Errors returned while locating or invoking a PHP constructor.
        pub const NewError = zend.Object.ConstructorError || zend.Function.Error;
        /// `NewError` plus converted Zend bailout errors.
        pub const TryNewError = zend.Object.ConstructorError || zend.Function.TryCallError;

        /// Creates a new instance and calls its PHP constructor when present.
        ///
        /// Ownership: caller owns the returned object reference. On constructor
        /// failure the newly created object is released automatically.
        /// `register()` must have succeeded before calling this function.
        pub fn new(params: anytype) NewError!*Self {
            const instance = create();
            const zend_object = instance.object();
            errdefer zend_object.release();
            if (try zend_object.constructor()) |constructor| try constructor.callMethod(zend_object, null, params);
            return instance;
        }
        /// Creates a new instance and calls its PHP constructor when present,
        /// converting Zend bailouts into errors.
        ///
        /// Ownership: caller owns the returned object reference. On constructor
        /// failure the newly created object is released automatically.
        /// `register()` must have succeeded before calling this function.
        pub fn tryNew(params: anytype) TryNewError!*Self {
            const instance = create();
            const zend_object = instance.object();
            errdefer zend_object.release();
            if (try zend_object.constructor()) |constructor| try constructor.tryCallMethod(zend_object, null, params);
            return instance;
        }
    };
}

fn bindMethods(
    comptime class_name: [:0]const u8,
    comptime T: type,
    comptime ClassType: type,
    comptime options: anytype,
    comptime resolved: Resolved(T),
) void {
    switch (resolved.binding_strategy) {
        .automatic => bindAutomatic(class_name, T, ClassType, resolved.layout, resolved.required_methods),
        .explicit => bindExplicit(class_name, T, ClassType, resolved.layout, resolved.required_methods, options.methods),
    }
}

fn bindExplicit(
    comptime class_name: [:0]const u8,
    comptime T: type,
    comptime ClassType: type,
    comptime class_layout: Layout,
    comptime methods: MethodMap,
    comptime bindings: anytype,
) void {
    const info = @typeInfo(@TypeOf(bindings)).@"struct";
    var bound: [methods.values().len]bool = @splat(false);
    comptime var message: []const u8 = "Class " ++ class_name ++ " .methods from Zig type '" ++ @typeName(@TypeOf(bindings)) ++ "' does not match the generated stub method table:";
    comptime var mismatch = false;

    inline for (info.field_names) |field_name| {
        const index = methods.getIndex(field_name) orelse {
            mismatch = true;
            message = message ++ "\n  not declared in generated stub: " ++ field_name;
            continue;
        };
        bound[index] = true;
    }
    inline for (methods.values(), bound) |method, is_bound| {
        if (!is_bound) {
            mismatch = true;
            message = message ++ "\n  missing Zig binding: " ++ method.name;
        }
    }
    if (mismatch) @compileError(message);

    inline for (info.field_names) |field_name| {
        const index = methods.getIndex(field_name).?;
        bind(class_name, T, ClassType, class_layout, methods.values()[index], @field(bindings, field_name));
    }
}

fn bindAutomatic(
    comptime class_name: [:0]const u8,
    comptime T: type,
    comptime ClassType: type,
    comptime class_layout: Layout,
    comptime methods: MethodMap,
) void {
    if (T == void) {
        if (methods.values().len != 0) @compileError("Class " ++ class_name ++ " requires methods but T is void");
        return;
    }

    var bound: [methods.values().len]bool = @splat(false);
    inline for (std.meta.declarations(T)) |decl_name| {
        const func = @field(T, decl_name);
        if (@typeInfo(@TypeOf(func)) != .@"fn") continue;

        const index = methods.getIndex(decl_name) orelse
            @compileError("Class " ++ class_name ++ " has unexpected public method '" ++ decl_name ++ "'");
        bound[index] = true;
        bind(class_name, T, ClassType, class_layout, methods.values()[index], func);
    }

    inline for (methods.values(), bound) |method, is_bound| {
        if (!is_bound) {
            @compileError("Class " ++ class_name ++ " does not implement required stub method '" ++ method.name ++ "'");
        }
    }
}

fn bind(
    comptime class_name: [:0]const u8,
    comptime T: type,
    comptime ClassType: type,
    comptime class_layout: Layout,
    comptime method: Method,
    comptime func: anytype,
) void {
    if (class_layout == .std) {
        function_helper.method(class_name, method.name, func);
        return;
    }
    if (std.mem.eql(u8, method.name, "__construct")) {
        bindConstructor(class_name, T, ClassType, func);
        return;
    }
    switch (method.kind) {
        .static => function_helper.method(class_name, method.name, func),
        .instance => bindInstanceMethod(class_name, T, ClassType, method.name, func),
    }
}

fn bindConstructor(comptime class_name: [:0]const u8, comptime T: type, comptime ClassType: type, comptime func: anytype) void {
    const Args = std.meta.ArgsTuple(@TypeOf(func));
    const handler: MethodHandler = struct {
        fn handle(execute_data: ?*c.zend_execute_data, return_value: ?*c.zval) callconv(abi.fn_cc) void {
            var ctx: Ctx = .{ .call = .from(execute_data.?), .ret = .from(return_value.?) };
            const self = ClassType.receiver(&ctx) orelse return;
            const args: Args = if (comptime @typeInfo(Args).@"struct".field_types.len == 1)
                .{ctx}
            else blk: {
                ctx.call.expectNoArgs() catch return;
                break :blk .{};
            };
            const value = @as(anyerror!T, @call(.auto, func, args)) catch |err| {
                if (err == error.ZendBailout or err == error.OutOfMemory) zend.bailout.raise();
                if (!errors.hasException()) {
                    errors.throwError(null, "%s at " ++ class_name ++ "::__construct()", .{@errorName(err).ptr});
                }
                return;
            };
            self.commitBacking(value);
        }
    }.handle;
    @export(&handler, .{ .name = stub.methodSymbolName(class_name, "__construct") });
}

fn bindInstanceMethod(comptime class_name: [:0]const u8, comptime T: type, comptime ClassType: type, comptime method_name: [:0]const u8, comptime func: anytype) void {
    const func_desc = class_name ++ "::" ++ method_name ++ "()";
    const params = @typeInfo(@TypeOf(func)).@"fn".param_types;
    if (params.len == 0 or (params[0] != *T and params[0] != *const T)) {
        @compileError("instance method " ++ func_desc ++ " must take *" ++ @typeName(T) ++ " or *const " ++ @typeName(T) ++ " as its first parameter");
    }
    if (params.len > 2 or (params.len == 2 and params[1] != Ctx)) {
        @compileError("unsupported instance method signature for " ++ func_desc ++ ": expected only an optional Ctx after the receiver");
    }

    const Args = std.meta.ArgsTuple(@TypeOf(func));
    const handler: MethodHandler = struct {
        fn handle(execute_data: ?*c.zend_execute_data, return_value: ?*c.zval) callconv(abi.fn_cc) void {
            var ctx: Ctx = .{ .call = .from(execute_data.?), .ret = .from(return_value.?) };
            const self = ClassType.receiver(&ctx) orelse return;
            const backing = self.backing() orelse {
                errors.throwError(null, class_name ++ " object is not initialized; call its constructor first", .{});
                return;
            };
            const args: Args = if (comptime params.len == 2)
                .{ backing, ctx }
            else blk: {
                ctx.call.expectNoArgs() catch return;
                break :blk .{backing};
            };
            _ = @as(anyerror!void, @call(.auto, func, args)) catch |err| {
                if (err == error.ZendBailout or err == error.OutOfMemory) zend.bailout.raise();
                if (!errors.hasException()) {
                    errors.throwError(null, "%s at " ++ func_desc, .{@errorName(err).ptr});
                }
            };
        }
    }.handle;
    @export(&handler, .{ .name = stub.methodSymbolName(class_name, method_name) });
}

test "concrete Zig class public declarations compile" {
    const Backing = struct { value: u8 };
    const register = struct {
        fn call() anyerror!*zend.ClassEntry {
            unreachable;
        }
    }.call;
    const TestClass = BackedClass("TestClass", Backing, .{}, .{
        .layout = .backed,
        .required_methods = MethodMap.initComptime(.{}),
        .binding_strategy = .automatic,
        .register = register,
        .init = null,
        .deinit = null,
        .clone = null,
        .handlers = .{},
    });

    std.testing.refAllDecls(TestClass);

    const VerifyGenericMethods = struct {
        fn new() TestClass.NewError!*TestClass {
            return TestClass.new(.{});
        }

        fn tryNew() TestClass.TryNewError!*TestClass {
            return TestClass.tryNew(.{});
        }
    };
    _ = &VerifyGenericMethods.new;
    _ = &VerifyGenericMethods.tryNew;
}

test {
    std.testing.refAllDecls(@This());
}
