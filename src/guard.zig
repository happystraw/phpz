//! Native resources owned by a managed PHP handler.
const std = @import("std");

const c = @import("c.zig").c;
const errors = @import("errors.zig");
const globals = @import("globals.zig");
const zend = @import("zend.zig");

pub const ScopeObject = extern struct {
    storage: [@sizeOf(Scope)]u8 align(@alignOf(Scope)),
    object: c.zend_object,

    const Self = @This();

    var entry: *c.zend_class_entry = undefined;
    var handlers: c.zend_object_handlers = undefined;

    comptime {
        if (@alignOf(Scope) > c.ZEND_MM_ALIGNMENT) {
            @compileError("guard scope alignment exceeds Zend MM alignment");
        }
    }

    inline fn scopeStorage(self: *Self) *Scope {
        return @ptrCast(@alignCast(&self.storage));
    }

    pub fn register(module_number: c_int) void {
        handlers = globals.stdObjectHandlers();
        handlers.offset = @offsetOf(Self, "object");
        handlers.free_obj = freeObject;
        handlers.get_constructor = getConstructor;
        handlers.clone_obj = null;
        entry = @ptrCast(c.phpz_register_guard_scope_class(module_number));
        c.phpz_class_entry_set_create_object(entry, createObject);
    }

    pub fn ensure(slot: *?*Scope) !*Scope {
        if (slot.*) |scope| return scope;
        const object = try create();
        const scope = object.scopeStorage();
        slot.* = scope;
        return scope;
    }

    pub fn release(scope: *Scope) void {
        const object: *Self = @ptrCast(@alignCast(scope));
        zend.Object.from(&object.object).release();
    }

    fn create() !*Self {
        const object = try zend.bailout.run(createObject, .{entry});
        return @fieldParentPtr("object", object.?);
    }

    fn getConstructor(_: ?*c.zend_object) callconv(.c) ?*c.zend_function {
        errors.throwError(null, "Instantiation of a Phpz guard scope is not allowed", .{}) catch {};
        return null;
    }

    fn createObject(ce: ?*c.zend_class_entry) callconv(.c) ?*c.zend_object {
        const intern: *Self = @ptrCast(@alignCast(c.zend_object_alloc(@sizeOf(Self), ce.?).?));
        intern.scopeStorage().* = Scope.init(std.heap.c_allocator);
        c.zend_object_std_init(&intern.object, ce.?);
        intern.object.handlers = &handlers;
        c.object_properties_init(&intern.object, ce.?);
        return &intern.object;
    }

    fn freeObject(obj: ?*c.zend_object) callconv(.c) void {
        const intern: *Self = @fieldParentPtr("object", obj.?);
        intern.scopeStorage().deinit();
        c.zend_object_std_dtor(obj);
    }
};

const Entry = struct {
    scope: *Scope,
    link: std.DoublyLinkedList.Node = .{},
    destroy_fn: *const fn (*Entry) void,

    fn detach(self: *Entry) void {
        self.scope.entries.remove(&self.link);
    }

    fn destroy(self: *Entry) void {
        self.detach();
        self.destroy_fn(self);
    }
};

/// Owns registered resources.
/// Keep its address stable until deinit; do not share it across threads or Fibers.
pub const Scope = struct {
    allocator: std.mem.Allocator,
    entries: std.DoublyLinkedList = .{},

    /// The allocator must remain valid after bailout and must not call PHP.
    pub fn init(allocator: std.mem.Allocator) Scope {
        return .{ .allocator = allocator };
    }

    /// Release remaining resources in reverse registration order.
    pub fn deinit(self: *Scope) void {
        while (self.entries.popLast()) |link| {
            const entry: *Entry = @fieldParentPtr("link", link);
            entry.destroy_fn(entry);
        }
    }

    /// Copy value into native storage; caller retains it on allocation failure.
    /// Cleanup must not call PHP, bailout, or register more resources.
    /// Stored pointers must outlive cleanup.
    pub fn register(self: *Scope, value: anytype, comptime cleanup: fn (@TypeOf(value)) void) std.mem.Allocator.Error!Guard(@TypeOf(value)) {
        const G = Guard(@TypeOf(value));
        const resource = try self.allocator.create(G.Resource);
        resource.* = .{
            .entry = .{
                .scope = self,
                .destroy_fn = struct {
                    fn call(entry: *Entry) void {
                        const owned: *G.Resource = @fieldParentPtr("entry", entry);
                        const allocator = entry.scope.allocator;
                        cleanup(owned.value);
                        allocator.destroy(owned);
                    }
                }.call,
            },
            .value = value,
        };
        self.entries.append(&resource.entry.link);
        return .{ .resource = resource };
    }
};

/// A handle to a resource registered in a Scope. Do not copy an active handle
/// or use it after the Scope ends. Zig does not release it automatically.
pub fn Guard(comptime T: type) type {
    return struct {
        const Self = @This();
        const Resource = struct {
            entry: Entry,
            value: T,
        };

        resource: ?*Resource,

        /// Borrow the stored resource until release, take, or scope cleanup.
        pub fn get(self: Self) *T {
            return &self.resource.?.value;
        }

        /// Unregister and release now. May be used with defer for earlier cleanup.
        pub fn release(self: *Self) void {
            const resource = self.resource orelse return;
            self.resource = null;
            resource.entry.destroy();
        }

        /// Unregister without cleanup, transferring ownership to the caller.
        pub fn take(self: *Self) T {
            const resource = self.resource.?;
            self.resource = null;
            const value = resource.value;
            resource.entry.detach();
            resource.entry.scope.allocator.destroy(resource);
            return value;
        }
    };
}

test "scope cleans remaining resources in reverse order after early release" {
    const Resource = struct {
        log: *[3]u8,
        count: *usize,
        id: u8,

        fn cleanup(self: @This()) void {
            self.log[self.count.*] = self.id;
            self.count.* += 1;
        }
    };
    var log: [3]u8 = undefined;
    var count: usize = 0;
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();
    _ = try scope.register(Resource{ .log = &log, .count = &count, .id = 1 }, Resource.cleanup);
    var middle = try scope.register(Resource{ .log = &log, .count = &count, .id = 2 }, Resource.cleanup);
    _ = try scope.register(Resource{ .log = &log, .count = &count, .id = 3 }, Resource.cleanup);
    middle.release();
    middle.release();
    scope.deinit();
    try std.testing.expectEqual(@as(usize, 3), count);
    try std.testing.expectEqualSlices(u8, &.{ 2, 3, 1 }, &log);
}

test "nested scopes preserve outer ownership and take cancels cleanup" {
    const Resource = struct {
        count: *usize,
        fn cleanup(self: @This()) void {
            self.count.* += 1;
        }
    };
    var outer_count: usize = 0;
    var inner_count: usize = 0;
    var outer = Scope.init(std.testing.allocator);
    defer outer.deinit();
    var inner = Scope.init(std.testing.allocator);
    defer inner.deinit();
    var kept = try outer.register(Resource{ .count = &outer_count }, Resource.cleanup);
    _ = try inner.register(Resource{ .count = &inner_count }, Resource.cleanup);
    inner.deinit();
    try std.testing.expectEqual(@as(usize, 1), inner_count);
    try std.testing.expectEqual(@as(usize, 0), outer_count);
    try std.testing.expect(kept.get().count == &outer_count);
    const value = kept.take();
    kept.release();
    outer.deinit();
    try std.testing.expectEqual(@as(usize, 0), outer_count);
    Resource.cleanup(value);
    try std.testing.expectEqual(@as(usize, 1), outer_count);
}

test "failed registration leaves ownership with caller" {
    const Resource = struct {
        fn cleanup(count: *usize) void {
            count.* += 1;
        }
    };
    var count: usize = 0;
    var scope = Scope.init(std.testing.failing_allocator);
    defer scope.deinit();
    try std.testing.expectError(error.OutOfMemory, scope.register(&count, Resource.cleanup));
    try std.testing.expectEqual(@as(usize, 0), count);
    Resource.cleanup(&count);
    try std.testing.expectEqual(@as(usize, 1), count);
}
