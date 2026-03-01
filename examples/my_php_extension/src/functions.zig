const std = @import("std");

const phpz = @import("phpz");
const c = phpz.c;
const errors = phpz.errors;

const gpa = @import("allocator.zig").gpa;
const HumanClass = @import("classes.zig").human.Class;

fn hello() void {
    _ = phpz.printf("Hello from ZIG!\n", .{});
}

fn whoami(ctx: *phpz.ExecContext, ret: *phpz.Zval) !void {
    var name: []u8 = undefined;
    var age_opt: phpz.Zval.Optional = .init;

    try ctx.parse("s|z!", .{ &name.ptr, &name.len, &age_opt.ptr });

    const result: []const u8 = if (age_opt.unwrap()) |age| blk: {
        if (age.is(.int)) {
            break :blk try std.fmt.allocPrint(gpa, "my name is {s}, i am {d} old", .{ name, age.asUnchecked(.int) });
        } else if (age.is(.string)) {
            break :blk try std.fmt.allocPrint(gpa, "my name is {s}, i am {s} old", .{ name, age.asUnchecked(.string) });
        } else if (age.is(.null)) {
            break :blk try std.fmt.allocPrint(gpa, "my name is {s}", .{name});
        } else {
            // Invalid type - throw TypeError
            return errors.argumentTypeError(2, "must be of type int|string|null, %s given", .{@tagName(age.kind()).ptr});
        }
    } else try std.fmt.allocPrint(gpa, "my name is {s}", .{name});
    defer gpa.free(result);

    ret.set(.string, result);
}

fn human(ctx: *phpz.ExecContext, ret: *phpz.Zval) !void {
    var name_zv: *c.zval = undefined;
    var age_zv: ?*c.zval = null;

    try ctx.parse("z|z!", .{ &name_zv, &age_zv });

    const human_obj: *HumanClass = .new();
    const human_std_obj: *phpz.zend.Object = .from(&human_obj.std);
    var call_params = [_]c.zval{
        name_zv.*,
        if (age_zv) |age| age.* else phpz.Zval.raw.init(.null, {}),
    };
    var call_ret: c.zval = undefined;
    defer c.zval_ptr_dtor(&call_ret);
    try human_std_obj.callMethodIfExists("__construct", &call_ret, &call_params);

    ret.set(.object, human_std_obj.ptr());
}

comptime {
    phpz.function("hello_world", hello);
    phpz.function("whoami", whoami);
    phpz.function("human", human);
}
