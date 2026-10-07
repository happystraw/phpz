const std = @import("std");

const phpz = @import("phpz");
const sapi = phpz.sapi;
const zend = phpz.zend;

var addon_module = blk: {
    phpz.functions(struct {
        pub fn custom_sapi_greeting() []const u8 {
            return "Hello from the built-in module";
        }
    }, .{});
    break :blk phpz.initModuleEntry(.{ .name = "custom_sapi_app" });
};

const Backend = struct {
    output: std.ArrayList(u8) = .empty,
    allocator: std.mem.Allocator,
    output_error: ?anyerror = null,

    fn write(self: *Backend, bytes: []const u8) !void {
        self.output.appendSlice(self.allocator, bytes) catch |err| {
            self.output_error = err;
            return err;
        };
    }
};
const Sapi = sapi.Sapi(Backend, .{
    .name = "custom_sapi",
    .pretty_name = "phpz Custom SAPI",
    .ub_write = Backend.write,
});

const Source = union(enum) {
    code: []const u8,
    file: [:0]u8,
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    var args = try init.minimal.args.iterateAllocator(gpa);
    defer args.deinit();
    _ = args.next();
    const input = args.next() orelse return error.ExpectedPhpScriptOrCode;
    const source: Source = if (std.mem.eql(u8, input, "-r"))
        .{ .code = args.next() orelse return error.ExpectedPhpCode }
    else
        .{ .file = try std.Io.Dir.cwd().realPathFileAlloc(init.io, input, gpa) };
    defer switch (source) {
        .file => |path| gpa.free(path),
        .code => {},
    };

    var backend: Backend = .{ .allocator = gpa };
    // Mandatory backend cleanup belongs to the host; deactivate may be skipped.
    defer backend.output.deinit(gpa);

    // Initialize TSRM for ZTS; no-op for NTS.
    try phpz.tsrm.startup();
    defer phpz.tsrm.shutdown();

    // Initialize Zend signal handling; no-op when disabled.
    zend.signal.startup();

    var custom_sapi = Sapi.init(.{
        .ini_ignore = true,
        .ini_ignore_cwd = true,
        .info_format = .text,
        .ini_entries = "display_errors=0\nlog_errors=1\n",
    });
    defer custom_sapi.deinit();

    try custom_sapi.startup(&addon_module);
    defer custom_sapi.shutdown();

    Sapi.setContext(&backend);
    defer Sapi.setContext(null);

    const request = phpz.globals.sapi().requestInfo();
    request.setPathTranslated(switch (source) {
        .file => |path| path,
        .code => null,
    });
    // Failure may leave a partially active request. Unwind the host and terminate;
    // do not retry startup or continue serving requests with this PHP runtime.
    try sapi.request.startup();
    var exit_status: phpz.errors.ExitStatus = .ok;
    const executed = blk: {
        // Keep context and source alive through shutdown functions and flush.
        defer {
            sapi.request.shutdown();
            exit_status = phpz.globals.executor().exitStatus();
            request.setPathTranslated(null);
        }
        switch (source) {
            .code => |text| {
                if (text.len != 0) phpz.tryEval(text, null, "Command line code") catch |err| {
                    if (err == error.PhpException) {
                        if (phpz.errors.takeUnwindExit()) |status| break :blk status == .ok;
                        // Reporting can run PHP __toString(), so it needs its own boundary.
                        if (phpz.errors.exception()) |exception| {
                            zend.bailout.run(phpz.errors.reportException, .{ exception, .err }) catch {};
                        }
                    }
                    break :blk false;
                };
            },
            .file => |path| {
                const file = try zend.bailout.run(zend.FileHandle.init, .{path});
                defer file.deinit();
                file.setPrimaryScript(true);
                phpz.tryExecuteScript(file) catch |err| {
                    // PHP consumes the exit exception and returns FAILURE even
                    // for exit(0). Bailouts and fatal errors must still fail.
                    break :blk err == error.ScriptExecutionFailed and
                        phpz.globals.executor().exitStatus() == .ok and
                        !phpz.globals.compiler().ptr().unclean_shutdown;
                };
            },
        }
        break :blk true;
    };
    // Request shutdown can append output; print only after it has completed.
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(backend.output.items);
    try stdout.interface.flush();
    if (backend.output_error) |err| return err;
    if (!executed or exit_status != .ok) return error.PhpScriptFailed;
}
