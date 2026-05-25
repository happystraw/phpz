const AbstractEntity = extern struct {
    pub fn register(impl: anytype) *phpz.ClassEntry {
        return .from(impl(Identifiable.entry.ptr()));
    }

    pub fn onLoad(ctx: phpz.Ctx) !void {
        const this = ctx.call.thisObject().?;

        var ret = phpz.Zval.native.undef;
        defer phpz.Zval.native.dtor(&ret);
        try this.call("getid", &ret, .{});

        const id = phpz.Zval.native.asUnchecked(&ret, .int);
        _ = phpz.printf("AbstractEntity::onLoad: getId() = %ld\n", .{id});
    }
};

pub const Class = phpz.Class("MyPHPExt\\AbstractEntity", AbstractEntity);

comptime {
    Class.method("onLoad", .onLoad);
}

const phpz = @import("phpz");
const c = phpz.c;

const Identifiable = @import("identifiable.zig").Interface;
