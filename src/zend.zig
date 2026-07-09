const std = @import("std");
const c = @import("c.zig").c;

pub const Array = @import("zend/array.zig").Array;
pub const Callable = @import("zend/callable.zig").Callable;
pub const ClassEntry = @import("zend/class_entry.zig").ClassEntry;
pub const Function = @import("zend/function.zig").Function;
pub const Object = @import("zend/object.zig").Object;
pub const PropertyInfo = @import("zend/property_info.zig").PropertyInfo;
pub const Reference = @import("zend/reference.zig").Reference;
pub const Resource = @import("zend/resource.zig").Resource;
pub const String = @import("zend/string.zig").String;
pub const try_catch = @import("zend/try_catch.zig");

pub inline fn bailout() noreturn {
    c.phpz_zend_bailout();
    unreachable;
}

pub const TryCatchError = try_catch.TryCatchError;
pub const TryCatchRawCallback = try_catch.TryCatchRawCallback;
pub const tryCatchRaw = try_catch.tryCatchRaw;
pub const firstTryCatchRaw = try_catch.firstTryCatchRaw;
pub const tryCatch = try_catch.tryCatch;
pub const firstTryCatch = try_catch.firstTryCatch;
pub const tryCatchTyped = try_catch.tryCatchTyped;
pub const firstTryCatchTyped = try_catch.firstTryCatchTyped;
pub const tryCatchSimple = try_catch.tryCatchSimple;
pub const firstTryCatchSimple = try_catch.firstTryCatchSimple;

test {
    std.testing.refAllDecls(@This());
}
