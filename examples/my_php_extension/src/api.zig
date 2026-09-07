pub const identifiable = @import("api/identifiable.zig");
pub const status = @import("api/status.zig");
pub const role = @import("api/role.zig");
pub const tag = @import("api/tag.zig");
pub const entity = @import("api/entity.zig");
pub const user = @import("api/user.zig");
pub const counter = @import("api/counter.zig");
pub const big_integer = @import("api/big_integer.zig");
pub const dumper = @import("api/dumper.zig");
pub const collection = @import("api/collection.zig");
pub const config = @import("api/config.zig");
pub const metrics = @import("api/metrics.zig");

pub const classes = &.{
    identifiable.Class,
    status.Class,
    role.Class,
    tag.Class,
    entity.Class,
    user.Class,
    counter.Class,
    big_integer.Class,
    dumper.Class,
    collection.Class,
    config.Class,
    metrics.Class,
};
