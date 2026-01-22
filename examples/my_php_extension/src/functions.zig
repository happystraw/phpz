fn hello_world() void {
    _ = phpz.printf("Hello from ZIG!\n", .{});
}

fn whoami(ctx: *phpz.ExecContext, ret: *phpz.Zval) !void {
    var name: []u8 = undefined;
    var age_opt: phpz.Zval.Optional = .init;

    try ctx.parse("s|z!", .{ &name.ptr, &name.len, &age_opt.inner });

    const result: []const u8 = if (age_opt.unwrap()) |age| blk: {
        if (age.is(.int)) {
            break :blk try std.fmt.allocPrint(gpa, "my name is {s}, i am {d} old", .{ name, age.asUnchecked(.int) });
        } else if (age.is(.string)) {
            break :blk try std.fmt.allocPrint(gpa, "my name is {s}, i am {s} old", .{ name, age.asUnchecked(.string) });
        } else if (age.is(.null)) {
            break :blk try std.fmt.allocPrint(gpa, "my name is {s}", .{name});
        } else {
            // Invalid type - throw TypeError
            c.zend_argument_type_error(2, "must be of type int|string|null, %s given", @tagName(age.kind()).ptr);
            return;
        }
    } else try std.fmt.allocPrint(gpa, "my name is {s}", .{name});
    defer gpa.free(result);

    ret.set(.string, result);
}

comptime {
    phpz.function("hello_world", hello_world);
    phpz.function("whoami", whoami);
}

const std = @import("std");

const phpz = @import("phpz");
const c = phpz.c;

const gpa = @import("allocator.zig").gpa;
