const phpz = @import("phpz");
const Zval = phpz.Zval;

/// PHP: MyPHPExt\Test\superglobalsSnapshot(): array
fn superglobalsSnapshot(ctx: phpz.Ctx) !void {
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
    result.set(.mixed, "GET", get.ptr());
    result.set(.mixed, "POST", post.ptr());
    result.set(.mixed, "COOKIE", cookie.ptr());
    result.set(.mixed, "SERVER", server.ptr());
    result.set(.mixed, "ENV", env.ptr());
    result.set(.mixed, "FILES", files.ptr());
    result.set(.mixed, "REQUEST", request.ptr());
}

/// PHP: MyPHPExt\Test\mutateSuperglobals(): void
fn mutateSuperglobals(ctx: phpz.Ctx) !void {
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

comptime {
    phpz.function("MyPHPExt\\Test\\superglobalsSnapshot", superglobalsSnapshot);
    phpz.function("MyPHPExt\\Test\\mutateSuperglobals", mutateSuperglobals);
}
