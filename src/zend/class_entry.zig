const std = @import("std");

const exception = @import("../exception.zig");
const globals = @import("../globals.zig");
const c = @import("../root.zig").c;
const Zval = @import("../zval.zig").Zval;
const Array = @import("array.zig").Array;
const ClassConstant = @import("class_constant.zig").ClassConstant;
const Function = @import("function.zig").Function;
const Object = @import("object.zig").Object;
const PropertyInfo = @import("property_info.zig").PropertyInfo;
const String = @import("string.zig").String;

pub const ClassEntry = opaque {
    /// Enum backing type classification.
    pub const EnumBackingType = enum(u32) {
        undef = c.IS_UNDEF,
        int = c.IS_LONG,
        string = c.IS_STRING,
        _,
    };

    /// Wrap a zend_class_entry pointer
    pub inline fn from(ce: *c.zend_class_entry) *ClassEntry {
        return @ptrCast(ce);
    }

    /// Get the underlying zend_class_entry pointer
    pub inline fn ptr(self: *ClassEntry) *c.zend_class_entry {
        return @ptrCast(@alignCast(self));
    }

    /// Borrow a built-in class entry by PHP class name or exact C symbol name.
    /// Resolves the symbol at compile time, then reads its global pointer directly.
    /// Does not query the class table or invoke autoloaders; the class must be initialized.
    pub inline fn builtin(comptime class_name: []const u8) *ClassEntry {
        return .from(globals.global(.value, *c.zend_class_entry, builtinSymbol(class_name)));
    }

    /// Look up a class in CG(class_table), during MINIT or a request.
    /// The table must be initialized; under ZTS it belongs to the current thread.
    ///
    /// The class table is keyed by lowercase names, so `class_name` must
    /// already be lowercase, without a leading backslash. This performs no
    /// normalization, autoloading, or linked-state check. Use `lookup` for
    /// case-insensitive lookup or autoloading.
    ///
    /// Ownership: borrowed class entry owned by the PHP runtime.
    /// Do not retain request-local class entries across requests or threads.
    pub fn find(class_name: []const u8) ?*ClassEntry {
        return globals.compiler().classes().findPtr(ClassEntry, class_name);
    }

    /// Look up a class by name, optionally invoking registered autoloaders.
    ///
    /// Requires an active request with an initialized executor and EG(class_table).
    /// Do not call during MINIT, even with `autoload = false`; use `builtin` or
    /// `find` for classes that have already been registered during startup.
    ///
    /// Unlike `find`, the name is normalized following Zend's rules
    /// (case-insensitive, with a leading namespace separator stripped).
    /// When `autoload` is true, registered autoload callbacks are run if the
    /// class is not already loaded; they may execute arbitrary PHP code and
    /// trigger a Zend bailout. Returns null if the class cannot be found without
    /// a pending exception; returns `error.PhpException` or `error.UnwindExit` if one
    /// is pending after lookup, including an exception raised by an autoloader.
    ///
    /// Ownership: borrowed class entry owned by the PHP runtime.
    pub fn lookup(class_name: []const u8, autoload: bool) exception.Error!?*ClassEntry {
        const zname = String.init(class_name, false);
        defer zname.release();

        const entry = c.zend_lookup_class_ex(zname.ptr(), null, if (autoload) 0 else c.ZEND_FETCH_CLASS_NO_AUTOLOAD);
        try exception.check();
        return if (entry) |ce| .from(ce) else null;
    }

    /// Get the class name as a byte slice
    pub fn name(self: *ClassEntry) [:0]const u8 {
        const n = self.ptr().*.name;
        return n.*.val()[0..n.*.len :0];
    }

    /// Get the parent class entry, or null if no parent
    pub fn parent(self: *ClassEntry) ?*ClassEntry {
        const p = c.phpz_class_entry_get_parent(self.ptr());
        return if (p) |parent_ptr| .from(parent_ptr) else null;
    }

    /// Get raw ce_flags
    pub inline fn flags(self: *ClassEntry) u32 {
        return @intCast(self.ptr().*.ce_flags);
    }

    /// Check if the class is abstract (explicit keyword or inherited abstract method)
    pub fn isAbstract(self: *ClassEntry) bool {
        const f = self.flags();
        return (f & c.ZEND_ACC_IMPLICIT_ABSTRACT_CLASS) != 0 or
            (f & c.ZEND_ACC_EXPLICIT_ABSTRACT_CLASS) != 0;
    }

    /// Check if the class is final
    pub fn isFinal(self: *ClassEntry) bool {
        return (self.flags() & c.ZEND_ACC_FINAL) != 0;
    }

    /// Check if the class is an interface
    pub fn isInterface(self: *ClassEntry) bool {
        return (self.flags() & c.ZEND_ACC_INTERFACE) != 0;
    }

    /// Check if the class is a trait
    pub fn isTrait(self: *ClassEntry) bool {
        return (self.flags() & c.ZEND_ACC_TRAIT) != 0;
    }

    /// Check if the class is an enum
    pub fn isEnum(self: *ClassEntry) bool {
        return (self.flags() & c.ZEND_ACC_ENUM) != 0;
    }

    /// Find a property by name in the class's properties_info table.
    ///
    /// Includes inherited entries present in the table. Returns null if the
    /// name is not found. Use PropertyInfo.declaringClass() to identify its declaring class.
    pub fn findPropertyInfo(self: *ClassEntry, prop_name: []const u8) ?*PropertyInfo {
        const info = c.zend_hash_str_find_ptr(&self.ptr().*.properties_info, prop_name.ptr, prop_name.len);
        return if (info != null) .from(@ptrCast(@alignCast(info))) else null;
    }

    /// Iterate over properties_info, including inherited entries.
    /// Use PropertyInfo.declaringClass() to identify the declaring class of each entry.
    pub fn propertyInfoIterator(self: *ClassEntry) Array.PtrValueIterator(PropertyInfo) {
        return .init(.from(&self.ptr().*.properties_info));
    }

    /// Find borrowed metadata in the class's active constant table, including inherited entries.
    /// Does not check visibility or evaluate expressions. Do not modify or release the entry.
    /// Use ClassConstant.declaringClass() to identify where the constant was declared.
    pub fn findConstant(self: *ClassEntry, constant_name: []const u8) ?*ClassConstant {
        const raw = c.zend_hash_str_find_ptr(c.zend_class_constants_table(self.ptr()), constant_name.ptr, constant_name.len);
        return if (raw != null) .from(@ptrCast(@alignCast(raw))) else null;
    }

    /// Read a constant from this registered class using the class itself as the
    /// access scope. Includes inherited constants and resolves constant expressions.
    /// Silent lookup returns null for missing/inaccessible constants; evaluation
    /// exceptions are still reported as PhpException or UnwindExit.
    ///
    /// Ownership: borrowed value owned by Zend; do not modify or release it.
    pub fn constant(self: *ClassEntry, constant_name: []const u8, silent: bool) exception.Error!?*Zval {
        const key = String.init(constant_name, false);
        defer key.release();
        const fetch_flags: u32 = if (silent) c.ZEND_FETCH_CLASS_EXCEPTION | c.ZEND_FETCH_CLASS_SILENT else c.ZEND_FETCH_CLASS_EXCEPTION;
        const value = c.zend_get_class_constant_ex(self.ptr().name, key.ptr(), self.ptr(), fetch_flags);
        try exception.check();
        return if (value) |v| .from(v) else null;
    }

    /// Get the class method table.
    /// Ownership: borrowed array owned by this class entry.
    pub inline fn methods(self: *ClassEntry) *Array {
        return Array.from(&self.ptr().*.function_table);
    }

    /// Find a method by name (lowercase) in the class function table
    pub fn findMethod(self: *ClassEntry, method_name: []const u8) ?*Function {
        return Function.findMethod(self, method_name);
    }

    pub const CallError = error{MethodNotFound} || Function.Error;
    pub const TryCallError = error{MethodNotFound} || Function.TryCallError;

    /// Call a known static method from this class's function table.
    /// Pass a lowercase method name; no visibility checks or __callStatic resolution.
    /// The method must be static. This class is used as the called scope.
    /// Arguments and result ownership follow Function.callStatic().
    pub fn callStatic(
        self: *ClassEntry,
        method_name: []const u8,
        retval: ?*c.zval,
        params: anytype,
        named_params: ?*Array,
    ) CallError!void {
        const method = self.findMethod(method_name) orelse return error.MethodNotFound;
        try method.callStatic(self, retval, params, named_params);
    }

    /// Call a known static method and convert a Zend bailout into ZendBailout.
    /// Arguments, ownership and bailout handling follow Function.tryCallStatic().
    pub fn tryCallStatic(
        self: *ClassEntry,
        method_name: []const u8,
        retval: ?*c.zval,
        params: anytype,
        named_params: ?*Array,
    ) TryCallError!void {
        const method = self.findMethod(method_name) orelse return error.MethodNotFound;
        try method.tryCallStatic(self, retval, params, named_params);
    }

    /// Get the class constructor, or null if this class has none
    pub fn constructor(self: *ClassEntry) ?*Function {
        const ctor = self.ptr().*.constructor;
        return if (ctor) |f| .from(f) else null;
    }

    /// Get the number of implemented interfaces
    pub inline fn interfaceCount(self: *ClassEntry) u32 {
        return self.ptr().*.num_interfaces;
    }

    /// Get an implemented interface by index (0-based), or null if out of range
    pub fn interfaceAt(self: *ClassEntry, index: u32) ?*ClassEntry {
        if (index >= self.interfaceCount()) return null;
        return .from(c.phpz_class_entry_get_interface(self.ptr(), index));
    }

    /// Check if this class implements a given interface
    pub fn implements(self: *ClassEntry, iface: *ClassEntry) bool {
        return c.zend_class_implements_interface(self.ptr(), iface.ptr());
    }

    /// Get the backing type of this enum class
    pub inline fn enumBackingType(self: *ClassEntry) EnumBackingType {
        return @fromBackingInt(self.ptr().*.enum_backing_type);
    }

    /// Get an enum case object by name.
    ///
    /// Ownership: borrowed case object owned by the enum class.
    ///
    /// Returns null if this class is not an enum or `case_name` is not one of
    /// its cases, including when it names a regular class constant.
    pub fn getEnumCase(self: *ClassEntry, case_name: [:0]const u8) ?*Object {
        if (!self.isEnum()) return null;
        const case_constant = self.findConstant(case_name) orelse return null;
        if (!case_constant.isEnumCase()) return null;
        return self.getEnumCaseUnchecked(case_name);
    }

    /// Get an enum case object by name without validating it.
    ///
    /// Ownership: borrowed case object owned by the enum class.
    ///
    /// `self` must be an enum and `case_name` one of its cases. Zend does not
    /// check either: debug builds assert, release builds dereference a null
    /// constant or return a non-object value.
    pub fn getEnumCaseUnchecked(self: *ClassEntry, case_name: [:0]const u8) *Object {
        return .from(c.zend_enum_get_case_cstr(self.ptr(), case_name.ptr).?);
    }

    pub const SetStaticPropertyError = error{UpdateStaticPropertyFailed} || exception.Error;

    /// Set static property value. Refcounted inputs are borrowed; `.mixed` must
    /// already be dereferenced. The caller keeps its input reference on
    /// both success and failure.
    /// `.reference` is not accepted; pass `reference.val()` with `.mixed` instead.
    /// Returns `error.PhpException` or `error.UnwindExit` for a pending PHP exception, otherwise
    /// `error.UpdateStaticPropertyFailed` if Zend reports failure.
    pub fn setStaticProperty(self: *ClassEntry, comptime zk: Zval.Kind, prop_name: []const u8, prop_value: Zval.Type(zk)) SetStaticPropertyError!void {
        const ce = self.ptr();
        const result = switch (zk) {
            .null => c.zend_update_static_property_null(ce, prop_name.ptr, prop_name.len),
            .bool => c.zend_update_static_property_bool(ce, prop_name.ptr, prop_name.len, if (prop_value) 1 else 0),
            .int => c.zend_update_static_property_long(ce, prop_name.ptr, prop_name.len, prop_value),
            .float => c.zend_update_static_property_double(ce, prop_name.ptr, prop_name.len, prop_value),
            .string => c.zend_update_static_property_stringl(ce, prop_name.ptr, prop_name.len, prop_value.ptr, prop_value.len),
            .mixed => blk: {
                std.debug.assert(!Zval.raw.is(prop_value, .reference));
                break :blk c.zend_update_static_property(ce, prop_name.ptr, prop_name.len, prop_value);
            },
            .reference => @compileError("property writes do not accept .reference; pass reference.val() with .mixed instead"),
            .undef, .indirect, .ptr => @compileError("'" ++ @tagName(zk) ++ "' cannot be set as static property"),
            inline else => blk: {
                var zv: c.zval = undefined;
                Zval.raw.set(&zv, zk, prop_value);
                break :blk c.zend_update_static_property(ce, prop_name.ptr, prop_name.len, &zv);
            },
        };
        try exception.check();
        if (result != c.SUCCESS) return error.UpdateStaticPropertyFailed;
    }

    /// Read a static property using this class as the access scope.
    ///
    /// Returns `error.PhpException` or `error.UnwindExit` for a pending PHP exception, even if Zend
    /// returned a non-null pointer. A null result means Zend returned no slot
    /// without an exception, such as a missing property when `silent` is true.
    /// Silent reads can return an IS_UNDEF slot for an uninitialized typed
    /// property; they do not suppress exceptions from class initialization.
    ///
    /// Ownership: borrowed property slot owned by PHP; do not release it.
    pub fn staticProperty(self: *ClassEntry, prop_name: []const u8, silent: bool) exception.Error!?*Zval {
        const val = c.zend_read_static_property(self.ptr(), prop_name.ptr, prop_name.len, silent);
        try exception.check();
        return if (val) |value| .from(value) else null;
    }
};

fn builtinSymbolName(comptime prefix: []const u8, comptime class_name: []const u8, comptime lowercase: bool) []const u8 {
    const name = if (class_name.len > 0 and class_name[0] == '\\') class_name[1..] else class_name;
    if (name.len == 0) @compileError("class entry name cannot be empty");

    comptime var result: [prefix.len + name.len]u8 = undefined;
    inline for (prefix, 0..) |ch, i| {
        result[i] = ch;
    }
    inline for (name, 0..) |ch, i| {
        result[prefix.len + i] = comptime switch (ch) {
            '\\' => '_',
            else => if (lowercase) std.ascii.toLower(ch) else ch,
        };
    }

    const final = result;
    return &final;
}

fn builtinSymbol(comptime class_name: []const u8) []const u8 {
    return comptime blk: {
        if (@hasDecl(c, class_name)) break :blk class_name;

        const zend_original = builtinSymbolName("zend_ce_", class_name, false);
        if (@hasDecl(c, zend_original)) break :blk zend_original;

        const zend_lowercase = builtinSymbolName("zend_ce_", class_name, true);
        if (@hasDecl(c, zend_lowercase)) break :blk zend_lowercase;

        const spl_original = builtinSymbolName("spl_ce_", class_name, false);
        if (@hasDecl(c, spl_original)) break :blk spl_original;

        const spl_lowercase = builtinSymbolName("spl_ce_", class_name, true);
        if (@hasDecl(c, spl_lowercase)) break :blk spl_lowercase;

        @compileError("class entry symbol not found: " ++ zend_original ++ ", " ++ zend_lowercase ++ ", " ++ spl_original ++ ", or " ++ spl_lowercase);
    };
}

test {
    @import("std").testing.refAllDecls(ClassEntry);
}
