const phpz = @import("phpz");
const Zval = phpz.Zval;

/// PHP: MyPHPExt\Test\superglobalsSnapshot(): array
pub fn superglobalsSnapshot(ctx: phpz.Ctx) !void {
    _ = try ctx.call.expectArgs(&.{}, {});

    const php = phpz.globals.php();
    const executor = phpz.globals.executor();
    const get = php.httpGlobal(.GET) orelse return error.SuperglobalUnavailable;
    const post = php.httpGlobal(.POST) orelse return error.SuperglobalUnavailable;
    const cookie = php.httpGlobal(.COOKIE) orelse return error.SuperglobalUnavailable;
    const server = php.httpGlobal(.SERVER) orelse return error.SuperglobalUnavailable;
    const env = php.httpGlobal(.ENV) orelse return error.SuperglobalUnavailable;
    const files = php.httpGlobal(.FILES) orelse return error.SuperglobalUnavailable;
    const request = executor.superglobal(.REQUEST) orelse return error.SuperglobalUnavailable;

    const result = Zval.Array.empty(ctx.ret.ptr());
    setBorrowed(result, "GET", get);
    setBorrowed(result, "POST", post);
    setBorrowed(result, "COOKIE", cookie);
    setBorrowed(result, "SERVER", server);
    setBorrowed(result, "ENV", env);
    setBorrowed(result, "FILES", files);
    setBorrowed(result, "REQUEST", request);
}

fn setBorrowed(result: *Zval.Array, key: []const u8, value: *Zval.Array) void {
    value.zval().addref();
    result.set(.mixed, key, value.ptr());
}

/// PHP: MyPHPExt\Test\mutateSuperglobals(): void
pub fn mutateSuperglobals(ctx: phpz.Ctx) !void {
    _ = try ctx.call.expectArgs(&.{}, {});

    const executor = phpz.globals.executor();
    const get = executor.superglobalMut(.GET) orelse return error.SuperglobalUnavailable;
    const post = executor.superglobalMut(.POST) orelse return error.SuperglobalUnavailable;
    const cookie = executor.superglobalMut(.COOKIE) orelse return error.SuperglobalUnavailable;
    const server = executor.superglobalMut(.SERVER) orelse return error.SuperglobalUnavailable;
    const env = executor.superglobalMut(.ENV) orelse return error.SuperglobalUnavailable;
    const files = executor.superglobalMut(.FILES) orelse return error.SuperglobalUnavailable;
    const request = executor.superglobalMut(.REQUEST) orelse return error.SuperglobalUnavailable;

    get.set(.string, "from_zig", "get");
    post.set(.string, "from_zig", "post");
    cookie.set(.string, "from_zig", "cookie");
    server.set(.string, "from_zig", "server");
    env.set(.string, "from_zig", "env");
    files.set(.string, "from_zig", "files");
    request.set(.string, "from_zig", "request");
}
