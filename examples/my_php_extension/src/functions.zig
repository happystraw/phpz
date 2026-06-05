const std = @import("std");

const phpz = @import("phpz");
const c = phpz.c;
const Zval = phpz.Zval;

const StatusEnum = @import("classes.zig").status.Enum;
const UserClass = @import("classes.zig").user.Class;

fn hello() void {
    _ = phpz.printf("Hello from ZIG!\n", .{});
}

fn greet(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
    }, {});
    const name = args[0];

    var buffer: [4096]u8 = undefined;
    const result: []const u8 = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{name});

    ctx.ret.set(.string, result);
}

fn increment(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .reference = .{} },
    }, {});
    const zv = args[0];
    const raw = zv.val();
    const current = Zval.native.asUnchecked(raw, .int);
    Zval.native.set(raw, .int, current + 1);
}

fn findById(ctx: phpz.Ctx) !void {
    ctx.ret.set(.null, {});
}

fn getDefaultUser(ctx: phpz.Ctx) !void {
    var name_zv = Zval.native.init(.string, "Default");
    defer Zval.native.dtor(&name_zv);
    const age_zv = Zval.native.init(.int, 25);

    const user: *UserClass = try .newWith(.{ name_zv, age_zv });
    ctx.ret.set(.object, .from(&user.std));
}

fn listStatuses(ctx: phpz.Ctx) !void {
    const cases_fn = StatusEnum.entry.findMethod("cases").?;

    var cases_zv: c.zval = undefined;
    try cases_fn.callStatic(StatusEnum.entry, &cases_zv, .{});
    defer phpz.Zval.native.dtor(&cases_zv);

    var ret = phpz.Zval.Array.empty(ctx.ret.ptr());
    var cases = phpz.Zval.native.asUnchecked(&cases_zv, .array);
    var it = cases.fastValueIterator();
    while (it.next()) |zv| {
        const entry_obj = phpz.Zval.native.asUnchecked(zv, .object);
        const name = entry_obj.enumCaseName();
        const value = phpz.Zval.native.asUnchecked(entry_obj.enumCaseValue().?, .int);
        ret.set(.int, name, value);
    }
}

/// Test expectArgs with all scalar types: .string, .int, .float, .bool.
/// Covers: required, optional, nullable, and zval flag.
fn testExpectArgScalars(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
        .{ .int = .{} },
        .{ .float = .{} },
        .{ .bool = .{ .optional = true } },
        .{ .string = .{ .optional = true, .nullable = true } },
        .{ .int = .{ .optional = true, .zval = true } },
    }, {});

    const str: []const u8 = args[0];
    const int_val: i64 = args[1];
    const float_val: f64 = args[2];
    const flag: bool = args[3] orelse true;
    const nullable_str: ?phpz.Ctx.Call.Nullable([]const u8) = args[4];
    const opt_int_zv: ?*c.zval = args[5];

    var result = phpz.Zval.Array.empty(ctx.ret.ptr());
    result.set(.string, "str", str);
    result.set(.int, "int", int_val);
    result.set(.float, "float", float_val);
    result.set(.bool, "flag", flag);

    if (nullable_str) |ns| {
        switch (ns) {
            .null => result.set(.null, "nullable_str", {}),
            .value => |s| result.set(.string, "nullable_str", s),
        }
    } else {
        result.set(.null, "nullable_str", {});
    }

    if (opt_int_zv) |zv| {
        if (Zval.native.is(zv, .int)) {
            result.set(.int, "opt_int", Zval.native.asUnchecked(zv, .int));
        } else {
            result.set(.null, "opt_int", {});
        }
    } else {
        result.set(.int, "opt_int", 0);
    }
}

/// Test expectArgs with .array and .object+class (required and nullable optional).
/// Covers: class instanceof checks, nullable class with null passed.
fn testExpectArgArrayObject(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .array = .{} },
        .{ .object = .{ .instanceof = true } },
        .{ .object = .{ .instanceof = true, .optional = true, .nullable = true } },
    }, .{
        {},
        .{ .class = UserClass.entry },
        .{ .class = UserClass.entry },
    });

    const data: *phpz.zend.Array = args[0];
    const user: *phpz.zend.Object = args[1];
    const nullable_user: ?phpz.Ctx.Call.Nullable(*phpz.zend.Object) = args[2];

    var result = phpz.Zval.Array.empty(ctx.ret.ptr());
    result.set(.int, "data_count", @intCast(data.len()));

    // Extract user name via readProperty
    const user_name_zv = try user.readProperty("name");
    if (user_name_zv) |zv| {
        if (Zval.native.is(zv, .string)) {
            result.set(.string, "user_name", Zval.native.asUnchecked(zv, .string));
        } else {
            result.set(.string, "user_name", "not_a_string");
        }
    } else {
        result.set(.string, "user_name", "?");
    }

    if (nullable_user) |nu| {
        switch (nu) {
            .null => result.set(.null, "nullable_user", {}),
            .value => |obj| {
                const nu_name_zv = try obj.readProperty("name");
                if (nu_name_zv) |zv| {
                    if (Zval.native.is(zv, .string)) {
                        result.set(.string, "nullable_user", Zval.native.asUnchecked(zv, .string));
                    } else {
                        result.set(.string, "nullable_user", "not_a_string");
                    }
                } else {
                    result.set(.string, "nullable_user", "?");
                }
            },
        }
    } else {
        result.set(.null, "nullable_user", {});
    }
}

/// Test expectArgs with .mixed type — returns the raw zval pointer directly.
fn testExpectArgMixed(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .mixed = .{} },
    }, {});

    const zv: *c.zval = args[0];

    // Return the value back to PHP as-is (add refcount to prevent double-free)
    ctx.ret.ptr().* = zv.*;
    Zval.native.addref(ctx.ret.ptr());
}

fn map(ctx: phpz.Ctx) !void {
    var cb: phpz.zend.Callable = .nil;
    // TODO: more simple way to parse a callable arg without defining a target struct?
    const ht, _ = try ctx.call.expectArgs(
        &.{
            .{ .array = .{} },
            .{ .callable = .{ .target = true } },
        },
        .{
            {},
            .{ .cb = &cb },
        },
    );
    // _ = cb.parse(cb_zv, false, null); // parse twice !

    var result = phpz.Zval.Array.empty(ctx.ret.ptr());
    var it = ht.fastIterator();
    while (it.next()) |entry| {
        var rv = Zval.native.undef;
        try cb.withRetval(&rv).call(.{entry.value.*});

        switch (entry.key) {
            .string => |s| result.set(.mixed, s, &rv),
            .int => |i| try result.setAt(.mixed, i, &rv),
        }
    }
}

comptime {
    phpz.function("hello", hello);
    phpz.function("greet", greet);
    phpz.function("MyPHPExt\\increment", increment);
    phpz.function("MyPHPExt\\findById", findById);
    phpz.function("MyPHPExt\\getDefaultUser", getDefaultUser);
    phpz.function("MyPHPExt\\listStatuses", listStatuses);
    phpz.function("MyPHPExt\\map", map);
    phpz.function("MyPHPExt\\testExpectArgScalars", testExpectArgScalars);
    phpz.function("MyPHPExt\\testExpectArgArrayObject", testExpectArgArrayObject);
    phpz.function("MyPHPExt\\testExpectArgMixed", testExpectArgMixed);
}
