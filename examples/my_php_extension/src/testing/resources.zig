const phpz = @import("phpz");
const Resource = phpz.zend.Resource;
const allocator = phpz.heap.php_allocator;

const Value = struct { number: i64 };
threadlocal var destroyed: i64 = 0;

fn destroy(value: *Value) void {
    destroyed += 1;
    allocator.destroy(value);
}

const ValueResource = Resource.Typed(Value, .{ .name = "phpz-value", .destroy = destroy });
const OtherResource = Resource.Typed(Value, .{ .name = "phpz-other", .destroy = destroy });
pub const types = .{ ValueResource, OtherResource };

pub fn createResource(number: i64, other: bool) !*Resource {
    const value = try allocator.create(Value);
    value.* = .{ .number = number };
    return if (other) OtherResource.init(value) else ValueResource.init(value);
}

pub fn readResource(resource: *Resource, other: bool) !i64 {
    const value = if (other) try OtherResource.fetch(resource) else try ValueResource.fetch(resource);
    return value.number;
}

pub fn closeResource(resource: *Resource) void {
    resource.close();
}

pub fn resourceTypeName(resource: *Resource) ?[:0]const u8 {
    return resource.typeName();
}

pub fn checkResourceRelease() !bool {
    const before = destroyed;
    const resource = try createResource(101, false);
    resource.addref();
    resource.release();
    const retained = resource.refcount() == 1 and destroyed == before and
        (try ValueResource.fetch(resource)).number == 101;
    resource.release();
    if (!retained or destroyed != before + 1) return false;

    const closed = try createResource(102, false);
    closed.close();
    closed.release();
    return destroyed == before + 2;
}

pub fn resourceDestructions() i64 {
    return destroyed;
}
