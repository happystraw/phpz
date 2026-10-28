const std = @import("std");
const phpz = @import("phpz");
const Zval = phpz.Zval;
const Object = phpz.zend.Object;
const ObjectIterator = phpz.zend.ObjectIterator;

pub fn iterateObject(ctx: phpz.Ctx, object: *Object, limit_arg: ?i64) !void {
    const limit = limit_arg orelse -1;
    const iterator = try ObjectIterator.init(object, false);
    defer iterator.release();
    const out = Zval.Array.empty(ctx.retval.ptr());
    var count: i64 = 0;
    while ((limit < 0 or count < limit) and try iterator.valid()) : (count += 1) {
        const current = try iterator.current() orelse break;
        // A key callback can invalidate the iterator's borrowed current value.
        var value = Zval.raw.init(.mixed, current);
        defer Zval.raw.release(&value);
        var key = try iterator.key();
        defer Zval.raw.release(&key);
        var pair_storage = Zval.raw.undef;
        const pair = Zval.Array.init(&pair_storage, 2);
        errdefer Zval.raw.release(&pair_storage);
        try pair.append(.mixed, &key);
        key = Zval.raw.undef;
        try pair.append(.mixed, &value);
        value = Zval.raw.undef;
        try out.append(.mixed, &pair_storage);
        pair_storage = Zval.raw.undef;
        if (limit >= 0 and count + 1 == limit) break;
        try iterator.advance();
    }
}

pub fn incrementObjectIterator(object: *Object) !void {
    const iterator = try ObjectIterator.init(object, true);
    defer iterator.release();
    while (try iterator.valid()) {
        const current = try iterator.current() orelse break;
        Zval.raw.makeRef(current);
        const ref = Zval.raw.asUnchecked(current, .reference);
        const value = try Zval.raw.as(ref.val(), .int);
        try ref.set(.int, try std.math.add(phpz.c.zend_long, @intCast(value), 1));
        try iterator.advance();
    }
}
