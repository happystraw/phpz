const std = @import("std");

const phpz = @import("phpz");
const c = phpz.c;
const Zval = phpz.Zval;

const ini_config = @import("ini.zig");
const StatusEnum = @import("classes.zig").status.Enum;
const UserClass = @import("classes.zig").user.Class;

/// hello(): void
fn hello() void {
    _ = phpz.printf("Hello from ZIG!\n", .{});
}

/// greet(string $name): string
fn greet(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
    }, {});
    const name = args[0];

    var buffer: [4096]u8 = undefined;
    const result: []const u8 = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{name});

    ctx.ret.set(.string, result);
}

/// increment(int &$value): void
fn increment(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .reference = .{} },
    }, {});
    const zv = args[0];
    const raw = zv.val();
    const current = Zval.native.asUnchecked(raw, .int);
    Zval.native.set(raw, .int, current + 1);
}

/// findById(string|int $id): ?User
fn findById(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .mixed = .{ .unions = &.{ .int, .string } } },
    }, {});
    switch (args[0]) {
        .int => |id| _ = phpz.printf("Found user with ID %d: ", .{id}),
        .string => |name| _ = phpz.printf("Found user with name %s: ", .{name.ptr}),
    }
    ctx.ret.set(.null, {});
}

/// getDefaultUser(): User
fn getDefaultUser(ctx: phpz.Ctx) !void {
    var name_zv = Zval.native.init(.string, "Default");
    defer Zval.native.dtor(&name_zv);
    const age_zv = Zval.native.init(.int, 25);

    const user: *UserClass = try .new(.{ name_zv, age_zv });
    ctx.ret.set(.object, .from(&user.std));
}

/// listStatuses(): array
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

/// testExpectArgScalars(string $str, int $int, float $float, bool $flag = true, ?string $nullable_str = null, int $opt_int = 0): array
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

/// testExpectArgArrayObject(array $data, \MyPHPExt\User $user, ?\MyPHPExt\User $nullable_user = null): array
fn testExpectArgArrayObject(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .array = .{} },
        .{ .object = .{ .instanceof = true } },
        .{ .object = .{ .instanceof = true, .optional = true, .nullable = true } },
    }, .{
        {},
        .{ .type = UserClass.entry },
        .{ .type = UserClass.entry },
    });

    const data: *phpz.zend.Array = args[0];
    const user: *phpz.zend.Object = args[1];
    const nullable_user: ?phpz.Ctx.Call.Nullable(*phpz.zend.Object) = args[2];

    var result = phpz.Zval.Array.empty(ctx.ret.ptr());
    result.set(.int, "data_count", @intCast(data.len()));

    var user_name_scratch = Zval.native.undef;
    const user_name_zv = try user.readProperty("name", .read, &user_name_scratch);
    defer Zval.native.tryDtor(&user_name_scratch);
    if (Zval.native.is(user_name_zv, .string)) {
        result.set(.string, "user_name", Zval.native.asUnchecked(user_name_zv, .string));
    } else {
        result.set(.string, "user_name", "not_a_string");
    }

    if (nullable_user) |nu| {
        switch (nu) {
            .null => result.set(.null, "nullable_user", {}),
            .value => |obj| {
                var nu_name_scratch = Zval.native.undef;
                const nu_name_zv = try obj.readProperty("name", .read, &nu_name_scratch);
                defer Zval.native.tryDtor(&nu_name_scratch);
                if (Zval.native.is(nu_name_zv, .string)) {
                    result.set(.string, "nullable_user", Zval.native.asUnchecked(nu_name_zv, .string));
                } else {
                    result.set(.string, "nullable_user", "not_a_string");
                }
            },
        }
    } else {
        result.set(.null, "nullable_user", {});
    }
}

/// testExpectArgMixed(mixed $value): mixed
fn testExpectArgMixed(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .mixed = .{} },
    }, {});

    const zv: *c.zval = args[0];

    // Return the value back to PHP as-is (add refcount to prevent double-free)
    ctx.ret.ptr().* = zv.*;
    Zval.native.addref(ctx.ret.ptr());
}

fn setValueSummary(result: *phpz.Zval.Array, zv: *c.zval) void {
    const kind = Zval.native.kind(zv);

    result.set(.string, "kind", @tagName(kind));
    switch (kind) {
        .undef => result.set(.string, "value", "undef"),
        .null => result.set(.null, "value", {}),
        .int => result.set(.int, "value", Zval.native.asUnchecked(zv, .int)),
        .float => result.set(.float, "value", Zval.native.asUnchecked(zv, .float)),
        .string => result.set(.string, "value", Zval.native.asUnchecked(zv, .string)),
        .bool => result.set(.bool, "value", Zval.native.asUnchecked(zv, .bool)),
        else => result.set(.string, "value", @tagName(kind)),
    }
}

/// inspectObjectProperty(object $obj, string $name, bool $silent = false): array
fn inspectObjectProperty(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .object = .{} },
        .{ .string = .{} },
        .{ .bool = .{ .optional = true } },
    }, {});

    const obj: *phpz.zend.Object = args[0];
    const name: []const u8 = args[1];
    const silent: bool = args[2] orelse false;

    var scratch = Zval.native.undef;
    const val = if (silent)
        try obj.readProperty(name, .isset, &scratch)
    else
        try obj.readProperty(name, .read, &scratch);
    defer Zval.native.tryDtor(&scratch);

    var result = phpz.Zval.Array.empty(ctx.ret.ptr());
    result.set(.bool, "scratch", !Zval.native.is(&scratch, .undef));
    setValueSummary(result, val);
}

/// tryCreateInvalidUser(): void
fn tryCreateInvalidUser(ctx: phpz.Ctx) !void {
    _ = ctx;

    const bad_name = Zval.native.init(.int, 123);
    const age = Zval.native.init(.int, 1);
    const user = try UserClass.new(.{ bad_name, age });
    user.release();
}

fn exhaustPhpAllocator(scope_defer: *bool, cleanup_defer: *bool, freed_blocks: *usize) !void {
    const allocator = phpz.heap.php_allocator;

    defer scope_defer.* = true;

    var blocks: [64][]u8 = undefined;
    var count: usize = 0;
    defer {
        for (blocks[0..count]) |block| allocator.free(block);
        freed_blocks.* = count;
        cleanup_defer.* = true;
    }

    while (count < blocks.len) : (count += 1) {
        const block = try allocator.alloc(u8, 1024 * 1024);
        block[0] = @intCast(count);
        block[block.len - 1] = @intCast(count);
        blocks[count] = block;
    }
}

/// testHeapAllocatorBailout(): array
fn testHeapAllocatorBailout(ctx: phpz.Ctx) !void {
    _ = try ctx.call.expectArgs(&.{}, {});

    var scope_defer = false;
    var cleanup_defer = false;
    var freed_blocks: usize = 0;
    var out_of_memory = false;

    exhaustPhpAllocator(&scope_defer, &cleanup_defer, &freed_blocks) catch |err| switch (err) {
        error.OutOfMemory => out_of_memory = true,
    };

    var result = phpz.Zval.Array.empty(ctx.ret.ptr());
    result.set(.bool, "out_of_memory", out_of_memory);
    result.set(.bool, "scope_defer", scope_defer);
    result.set(.bool, "cleanup_defer", cleanup_defer);
    result.set(.bool, "freed_blocks", freed_blocks > 0);
}

/// map(array $arr, callable $cb): array
fn map(ctx: phpz.Ctx) !void {
    var cb: phpz.zend.Callable = .nil;
    // TODO: more simple way to parse a callable arg without defining a target struct?
    const ht, _ = try ctx.call.expectArgs(
        &.{
            .{ .array = .{} },
            .{ .callable = .{ .resolve = true } },
        },
        .{
            {},
            .{ .target = &cb },
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

/// iniGetGreeting(): string
fn iniGetGreeting(ctx: phpz.Ctx) !void {
    ctx.ret.set(.string, ini_config.greeting.get());
}

/// iniGetMaxUsers(): int
fn iniGetMaxUsers(ctx: phpz.Ctx) !void {
    ctx.ret.set(.int, ini_config.max_users.get());
}

/// iniGetDebug(): bool
fn iniGetDebug(ctx: phpz.Ctx) !void {
    ctx.ret.set(.bool, ini_config.debug.get());
}

/// iniGetMode(): string
fn iniGetMode(ctx: phpz.Ctx) !void {
    ctx.ret.set(.string, @tagName(ini_config.mode.get()));
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
    phpz.function("MyPHPExt\\inspectObjectProperty", inspectObjectProperty);
    phpz.function("MyPHPExt\\tryCreateInvalidUser", tryCreateInvalidUser);
    phpz.function("MyPHPExt\\testHeapAllocatorBailout", testHeapAllocatorBailout);
    phpz.function("iniGetGreeting", iniGetGreeting);
    phpz.function("iniGetMaxUsers", iniGetMaxUsers);
    phpz.function("iniGetDebug", iniGetDebug);
    phpz.function("iniGetMode", iniGetMode);
}
