const c = @import("../root.zig").c;
const Zval = @import("../zval.zig").Zval;
const Array = @import("array.zig").Array;
const Function = @import("function.zig").Function;
const Object = @import("object.zig").Object;
const PropertyInfo = @import("property_info.zig").PropertyInfo;

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

    /// Get the number of declared properties
    pub fn propertyCount(self: *ClassEntry) usize {
        return @intCast(self.ptr().*.properties_info.nNumOfElements);
    }

    /// Find a property by name (this class's own declarations only)
    pub fn findPropertyInfo(self: *ClassEntry, prop_name: []const u8) ?*PropertyInfo {
        return PropertyInfo.find(self, prop_name);
    }

    /// Iterate over this class's own declared properties
    pub fn propertyInfoIterator(self: *ClassEntry) Array.PtrValueIterator(PropertyInfo) {
        return PropertyInfo.iterator(self);
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

    /// Get an enum case object by name from this enum class
    pub fn getEnumCase(self: *ClassEntry, case_name: [:0]const u8) ?*Object {
        const case_obj = c.zend_enum_get_case_cstr(self.ptr(), case_name.ptr);
        return if (case_obj) |obj| Object.from(obj) else null;
    }

    pub const SetStaticPropertyError = error{UpdateStaticPropertyFailed};

    /// Set static property value. Returns `error.UpdateStaticPropertyFailed` on failure.
    pub fn setStaticProperty(self: *ClassEntry, comptime zk: Zval.Kind, prop_name: []const u8, prop_value: Zval.Type(zk)) SetStaticPropertyError!void {
        const ce = self.ptr();
        const result = switch (zk) {
            .null => c.zend_update_static_property_null(ce, prop_name.ptr, prop_name.len),
            .bool => c.zend_update_static_property_bool(ce, prop_name.ptr, prop_name.len, if (prop_value) 1 else 0),
            .int => c.zend_update_static_property_long(ce, prop_name.ptr, prop_name.len, prop_value),
            .float => c.zend_update_static_property_double(ce, prop_name.ptr, prop_name.len, prop_value),
            .string => c.zend_update_static_property_stringl(ce, prop_name.ptr, prop_name.len, prop_value.ptr, prop_value.len),
            .undef, .indirect, .ptr => @compileError("'" ++ @tagName(zk) ++ "' cannot be set as static property"),
            inline else => blk: {
                var zv: c.zval = undefined;
                Zval.raw.set(&zv, zk, prop_value);
                break :blk c.zend_update_static_property(ce, prop_name.ptr, prop_name.len, &zv);
            },
        };
        if (result != c.SUCCESS) return error.UpdateStaticPropertyFailed;
    }

    /// Read static property.
    pub fn staticProperty(self: *ClassEntry, prop_name: []const u8, silent: bool) *Zval {
        const val = c.zend_read_static_property(self.ptr(), prop_name.ptr, prop_name.len, silent);
        return .from(val);
    }
};

test {
    @import("std").testing.refAllDecls(ClassEntry);
}
