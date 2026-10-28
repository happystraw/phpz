const std = @import("std");
const c = @import("../root.zig").c;
const exception = @import("../exception.zig");

pub const Resource = opaque {
    /// Declare a request resource type with a typed payload and destructor.
    /// Register once during module startup, before creating or fetching resources.
    pub fn Typed(comptime T: type, comptime options: struct {
        name: [:0]const u8,
        destroy: fn (*T) void,
    }) type {
        return struct {
            var type_id: c_int = -1;

            /// Register the type and its destructor with Zend.
            pub fn register(module_number: c_int) error{ResourceRegistrationFailed}!void {
                type_id = c.zend_register_list_destructors_ex(resourceDtor, null, options.name.ptr, module_number);
                if (type_id == c.FAILURE) return error.ResourceRegistrationFailed;
            }

            /// Create a request resource taking ownership of value through options.destroy.
            /// Ownership: caller owns one resource reference.
            pub fn init(value: *T) *Resource {
                std.debug.assert(type_id >= 0);
                return Resource.from(c.zend_register_resource(value, type_id));
            }

            /// Borrow the payload after Zend checks the resource type and open state.
            /// Keep the resource alive and open while using the returned pointer.
            pub fn fetch(resource: *Resource) exception.Error!*T {
                std.debug.assert(type_id >= 0);
                const value = c.zend_fetch_resource(resource.ptr(), options.name.ptr, type_id) orelse
                    return exception.pending() orelse error.PhpException;
                return @ptrCast(@alignCast(value));
            }

            fn resourceDtor(resource: [*c]c.zend_resource) callconv(.c) void {
                options.destroy(@ptrCast(@alignCast(resource.*.ptr.?)));
            }
        };
    }

    /// Wrap an existing zend_resource pointer without changing ownership.
    pub inline fn from(res: *c.zend_resource) *Resource {
        return @ptrCast(res);
    }

    /// Get the underlying zend_resource pointer
    pub inline fn ptr(self: *Resource) *c.zend_resource {
        return @ptrCast(@alignCast(self));
    }

    /// Close the payload for all aliases without releasing this reference.
    pub fn close(self: *Resource) void {
        c.zend_list_close(self.ptr());
    }

    /// Release one owned reference, destroying the resource when the count reaches zero.
    pub fn release(self: *Resource) void {
        _ = c.zend_list_delete(self.ptr());
    }

    /// Get the resource handle (registered resource ID)
    pub inline fn handle(self: *Resource) i64 {
        return @intCast(self.ptr().handle);
    }

    /// Get the resource type ID, or -1 after closing.
    pub inline fn typeId(self: *Resource) c_int {
        return self.ptr().type;
    }

    /// Borrow the registered type name, or null for a closed or unknown resource type.
    pub fn typeName(self: *Resource) ?[:0]const u8 {
        const name = c.zend_rsrc_list_get_rsrc_type(self.ptr());
        if (name == null) return null;
        return std.mem.span(name);
    }

    /// Borrow the untyped payload pointer, or null after closing.
    pub inline fn data(self: *Resource) ?*anyopaque {
        return self.ptr().ptr;
    }

    /// Get refcount
    pub inline fn refcount(self: *Resource) u32 {
        return c.zend_gc_refcount(&self.ptr().gc);
    }

    /// Increment refcount
    pub fn addref(self: *Resource) void {
        _ = c.zend_gc_addref(&self.ptr().gc);
    }

    /// Decrement refcount without destroying the resource. Do not use for cleanup.
    pub fn delref(self: *Resource) void {
        _ = c.zend_gc_delref(&self.ptr().gc);
    }
};

test {
    std.testing.refAllDecls(Resource);
}
