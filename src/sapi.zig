const std = @import("std");

const c = @import("c.zig").c;
const globals = @import("globals.zig");
const bailout = @import("zend/bailout.zig");
const Zval = @import("zval.zig").Zval;
const ModuleEntry = @import("module.zig").ModuleEntry;

pub const Protocol = enum(i32) {
    http_0_9 = 9,
    http_1_0 = 1000,
    http_1_1 = 1001,
    http_2_0 = 2000,
    http_3_0 = 3000,
    _,
};

pub const Status = enum(i32) {
    @"continue" = 100,
    switching_protocols = 101,
    processing = 102,
    early_hints = 103,

    ok = 200,
    created = 201,
    accepted = 202,
    non_authoritative_info = 203,
    no_content = 204,
    reset_content = 205,
    partial_content = 206,
    multi_status = 207,
    already_reported = 208,
    im_used = 226,

    multiple_choice = 300,
    moved_permanently = 301,
    found = 302,
    see_other = 303,
    not_modified = 304,
    use_proxy = 305,
    temporary_redirect = 307,
    permanent_redirect = 308,

    bad_request = 400,
    unauthorized = 401,
    payment_required = 402,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    not_acceptable = 406,
    proxy_auth_required = 407,
    request_timeout = 408,
    conflict = 409,
    gone = 410,
    length_required = 411,
    precondition_failed = 412,
    payload_too_large = 413,
    uri_too_long = 414,
    unsupported_media_type = 415,
    range_not_satisfiable = 416,
    expectation_failed = 417,
    teapot = 418,
    misdirected_request = 421,
    unprocessable_entity = 422,
    locked = 423,
    failed_dependency = 424,
    too_early = 425,
    upgrade_required = 426,
    precondition_required = 428,
    too_many_requests = 429,
    request_header_fields_too_large = 431,
    unavailable_for_legal_reasons = 451,

    internal_server_error = 500,
    not_implemented = 501,
    bad_gateway = 502,
    service_unavailable = 503,
    gateway_timeout = 504,
    http_version_not_supported = 505,
    variant_also_negotiates = 506,
    insufficient_storage = 507,
    loop_detected = 508,
    not_extended = 510,
    network_authentication_required = 511,

    _,
};

pub const Globals = opaque {
    pub inline fn from(raw: *c.sapi_globals_struct) *Globals {
        return @ptrCast(raw);
    }

    pub inline fn ptr(self: *Globals) *c.sapi_globals_struct {
        return @ptrCast(@alignCast(self));
    }

    pub inline fn requestInfo(self: *Globals) *RequestInfo {
        return .from(&self.ptr().request_info);
    }

    pub inline fn headers(self: *Globals) *Headers {
        return .from(&self.ptr().sapi_headers);
    }

    pub fn headersSent(self: *Globals) bool {
        const value = self.ptr().headers_sent;
        return if (comptime @TypeOf(value) == bool) value else value != 0;
    }
};

pub const InfoFormat = enum(i32) {
    html = 0,
    text = 1,
    _,
};

/// Lifecycle of the current thread's PHP request.
pub const request = struct {
    /// Start a request after PHP module and thread initialization.
    /// Failure may leave partially activated PHP state; no rollback is performed.
    /// Treat failure as terminal for the host: shut down PHP modules, SAPI and
    /// TSRM before exiting, keeping borrowed backend resources alive through
    /// teardown. Do not retry or serve another request with this runtime.
    pub fn startup() error{RequestStartupFailed}!void {
        if (c.php_request_startup() != c.SUCCESS) return error.RequestStartupFailed;
    }

    /// Shut down a successfully started request on the same thread.
    /// Keep the SAPI context alive until this returns.
    pub fn shutdown() void {
        c.php_request_shutdown(null);
    }
};

/// Borrowed request metadata. String setters do not copy or free storage.
/// Keep assigned strings alive through request shutdown; string getters borrow them.
pub const RequestInfo = opaque {
    pub inline fn from(raw: *c.sapi_request_info) *RequestInfo {
        return @ptrCast(raw);
    }

    pub inline fn ptr(self: *RequestInfo) *c.sapi_request_info {
        return @ptrCast(@alignCast(self));
    }

    pub fn method(self: *RequestInfo) ?[:0]const u8 {
        const value = self.ptr().request_method;
        return if (value == null) null else std.mem.span(value);
    }

    pub fn setMethod(self: *RequestInfo, value: ?[:0]const u8) void {
        self.ptr().request_method = if (value) |str| str.ptr else null;
    }

    pub fn pathTranslated(self: *RequestInfo) ?[:0]const u8 {
        const value = self.ptr().path_translated;
        return if (value == null) null else std.mem.span(value);
    }

    pub fn setPathTranslated(self: *RequestInfo, value: ?[:0]u8) void {
        self.ptr().path_translated = if (value) |str| str.ptr else null;
    }

    pub fn requestUri(self: *RequestInfo) ?[:0]const u8 {
        const value = self.ptr().request_uri;
        return if (value == null) null else std.mem.span(value);
    }

    pub fn setRequestUri(self: *RequestInfo, value: ?[:0]u8) void {
        self.ptr().request_uri = if (value) |str| str.ptr else null;
    }

    pub fn queryString(self: *RequestInfo) ?[:0]const u8 {
        const value = self.ptr().query_string;
        return if (value == null) null else std.mem.span(value);
    }

    pub fn setQueryString(self: *RequestInfo, value: ?[:0]u8) void {
        self.ptr().query_string = if (value) |str| str.ptr else null;
    }

    pub fn contentType(self: *RequestInfo) ?[:0]const u8 {
        const value = self.ptr().content_type;
        return if (value == null) null else std.mem.span(value);
    }

    pub fn setContentType(self: *RequestInfo, value: ?[:0]const u8) void {
        self.ptr().content_type = if (value) |str| str.ptr else null;
    }

    pub fn contentLength(self: *RequestInfo) c.zend_long {
        return self.ptr().content_length;
    }

    pub fn setContentLength(self: *RequestInfo, value: c.zend_long) void {
        self.ptr().content_length = value;
    }

    pub fn noHeaders(self: *RequestInfo) bool {
        return self.ptr().no_headers;
    }

    /// PHP clears this during activation; set it in activate or after request startup.
    pub fn setNoHeaders(self: *RequestInfo, value: bool) void {
        self.ptr().no_headers = value;
    }

    pub fn protocol(self: *RequestInfo) Protocol {
        return @fromBackingInt(@intCast(self.ptr().proto_num));
    }

    /// PHP resets this to HTTP/1.0 during activation; set it in the activate hook.
    pub fn setProtocol(self: *RequestInfo, value: Protocol) void {
        self.ptr().proto_num = @intCast(@backingInt(value));
    }
};

/// Add a response header to the current request. PHP copies the bytes.
/// Requires an active request; does not catch PHP bailouts.
pub fn addHeader(line: []const u8) error{HeaderOperationFailed}!void {
    try headerOp(c.SAPI_HEADER_ADD, line);
}

/// Replace matching response headers in the current request. PHP copies the bytes.
/// Requires an active request; does not catch PHP bailouts.
pub fn replaceHeader(line: []const u8) error{HeaderOperationFailed}!void {
    try headerOp(c.SAPI_HEADER_REPLACE, line);
}

/// Delete a response header by name, without a colon, from the current request.
/// Requires an active request; does not catch PHP bailouts.
pub fn deleteHeader(name: []const u8) error{HeaderOperationFailed}!void {
    try headerOp(c.SAPI_HEADER_DELETE, name);
}

/// Delete all queued response headers in the current request.
/// Requires an active request; does not catch PHP bailouts.
pub fn deleteAllHeaders() error{HeaderOperationFailed}!void {
    if (c.sapi_header_op(c.SAPI_HEADER_DELETE_ALL, null) != c.SUCCESS)
        return error.HeaderOperationFailed;
}

/// Update the current response code using PHP's header rules.
/// Requires an active request; does not catch PHP bailouts.
pub fn setResponseCode(status: Status) error{HeaderOperationFailed}!void {
    // SAPI_HEADER_SET_STATUS takes the integer encoded as a pointer, not int *.
    const code: isize = @backingInt(status);
    if (c.sapi_header_op(c.SAPI_HEADER_SET_STATUS, @ptrFromInt(@as(usize, @bitCast(code)))) != c.SUCCESS)
        return error.HeaderOperationFailed;
}

/// Send the current response headers using PHP's header handling.
/// Requires an active request; does not catch PHP bailouts.
pub fn sendHeaders() error{SendHeadersFailed}!void {
    if (c.sapi_send_headers() != c.SUCCESS) return error.SendHeadersFailed;
}

/// Invoke the SAPI flush hook, without draining PHP output buffers.
/// Fails if no hook is installed; hook errors follow the hook's own handling.
/// Requires an active request; does not catch PHP bailouts.
pub fn flush() error{FlushFailed}!void {
    if (c.sapi_flush() != c.SUCCESS) return error.FlushFailed;
}

/// Get the current request's timestamp in seconds since the Unix epoch.
/// Uses PHP's cached value, SAPI hook, and clock fallback. Requires an active request.
pub fn requestTime() f64 {
    return c.sapi_get_request_time();
}

fn headerOp(op: c.sapi_header_op_enum, line: []const u8) error{HeaderOperationFailed}!void {
    var header = std.mem.zeroes(c.sapi_header_line);
    header.line = line.ptr;
    header.line_len = line.len;
    if (c.sapi_header_op(op, &header) != c.SUCCESS)
        return error.HeaderOperationFailed;
}

pub const Headers = opaque {
    pub inline fn from(raw: *c.sapi_headers_struct) *Headers {
        return @ptrCast(raw);
    }

    pub inline fn ptr(self: *Headers) *c.sapi_headers_struct {
        return @ptrCast(@alignCast(self));
    }

    pub fn status(self: *Headers) Status {
        return @fromBackingInt(@intCast(self.ptr().http_response_code));
    }
    /// Set the stored response code; this does not send headers.
    pub fn setStatus(self: *Headers, value: Status) void {
        self.ptr().http_response_code = @intCast(@backingInt(value));
    }
    pub fn sendDefaultContentType(self: *Headers) bool {
        return self.ptr().send_default_content_type != 0;
    }
    pub fn mimetype(self: *Headers) ?[]const u8 {
        return if (self.ptr().mimetype == null) null else std.mem.span(self.ptr().mimetype);
    }
    pub fn statusLine(self: *Headers) ?[]const u8 {
        return if (self.ptr().http_status_line == null) null else std.mem.span(self.ptr().http_status_line);
    }
    pub fn iterator(self: *Headers) Iterator {
        return .{ .list = &self.ptr().headers };
    }
    pub const Iterator = struct {
        list: *c.zend_llist,
        position: c.zend_llist_position = null,
        started: bool = false,

        pub fn next(self: *Iterator) ?struct { line: []const u8 } {
            const element = if (self.started)
                c.zend_llist_get_next_ex(self.list, &self.position)
            else blk: {
                self.started = true;
                break :blk c.zend_llist_get_first_ex(self.list, &self.position);
            };
            const header: *c.sapi_header_struct = @ptrCast(@alignCast(element orelse return null));
            return .{ .line = header.header[0..header.header_len] };
        }
    };
};

/// Borrowed variable array; registration requires mutable, uniquely owned storage.
pub const ServerVars = opaque {
    pub inline fn from(raw: *c.zval) *ServerVars {
        return @ptrCast(raw);
    }

    pub inline fn ptr(self: *ServerVars) *c.zval {
        return @ptrCast(@alignCast(self));
    }

    /// Copy a binary-safe string, applying PHP's variable-name normalization.
    pub fn registerVariableSafe(self: *ServerVars, name: [:0]const u8, value: []const u8) void {
        c.php_register_variable_safe(name.ptr, value.ptr, value.len, self.ptr());
    }

    /// Normalize the name and consume value's contents, even when the name is rejected.
    /// Does not clear value; copy/addref borrowed contents first and do not release twice.
    pub fn registerVariableEx(self: *ServerVars, name: [:0]const u8, value: *Zval) void {
        c.php_register_variable_ex(name.ptr, value.ptr(), self.ptr());
    }

    /// Consume value's contents without name parsing; does not clear value.
    /// Name must be nonempty, nonnumeric, not GLOBALS/this, and contain no NUL, space, dot or '['.
    /// Do not use on the cookie array; copy/addref borrowed contents before transfer.
    pub fn registerKnownVariable(self: *ServerVars, name: []const u8, value: *Zval) void {
        c.php_register_known_variable(name.ptr, name.len, value.ptr(), self.ptr());
    }
};

/// Callbacks use the backend bound with Sapi.setContext.
pub fn Options(comptime T: type) type {
    return struct {
        /// SAPI identifier exposed as PHP_SAPI.
        name: [:0]const u8,
        /// Display name; defaults to name.
        pretty_name: ?[:0]const u8 = null,
        /// Write all output bytes; the slice is borrowed for this call.
        /// Errors mark the connection aborted; ignore_user_abort controls termination.
        ub_write: fn (*T, []const u8) anyerror!void,
        /// Flush buffered output to the client.
        /// Errors use the same connection-abort handling as ub_write.
        flush: ?fn (*T) anyerror!void = null,
        /// Send the response headers; the header view is borrowed.
        /// Errors report header-send failure to PHP.
        send_headers: ?fn (*T, *Headers) anyerror!void = null,
        /// Fill the borrowed buffer up to the request-body boundary; a short read means EOF.
        /// Handle transport short reads internally. May run before activate and during shutdown.
        /// Errors abort the current PHP operation via bailout. During shutdown this
        /// can skip deactivate; mandatory backend cleanup must be owned by the host.
        read_post: ?fn (*T, []u8) anyerror!usize = null,
        /// Return borrowed cookie text that remains valid through request shutdown.
        /// Called before activate; errors abort request activation via bailout.
        read_cookies: ?fn (*T) anyerror!?[:0]u8 = null,
        /// Populate PHP's server variables using the borrowed array view.
        /// May run lazily when $_SERVER is accessed; errors raise a bailout.
        register_server_variables: ?fn (*T, *ServerVars) anyerror!void = null,
        /// Log a borrowed message and PHP's syslog severity, or -1 for phpz hook errors.
        log_message: ?fn (*T, []const u8, i32) void = null,
        /// Run after POST pre-reading and cookie retrieval; prepare their state beforehand.
        /// Errors abort request activation via bailout.
        activate: ?fn (*T) anyerror!void = null,
        /// Notify the backend after output and input cleanup; queued headers are already freed.
        /// May be skipped by a bailout while PHP drains the request body, or by startup failure.
        /// Keep mandatory resource cleanup in the host, outside PHP bailout boundaries.
        /// Errors are logged only and do not propagate to request.shutdown.
        deactivate: ?fn (*T) anyerror!void = null,
    };
}

pub const InitOptions = struct {
    ini_ignore: bool = false,
    ini_ignore_cwd: bool = false,
    info_format: InfoFormat = .html,
    /// Borrowed INI text; keep it alive through PHP module shutdown.
    ini_entries: ?[:0]const u8 = null,
};

/// Owns a local module table for PHP's process-global SAPI lifecycle.
/// Initialize TSRM and signals first.
pub fn Sapi(comptime T: type, comptime options: Options(T)) type {
    return struct {
        entry: c.sapi_module_struct,

        const Self = @This();

        /// Initialize SAPI state, without starting PHP modules or a request.
        /// Only one SAPI may be active. Keep this instance alive until deinit().
        pub fn init(config: InitOptions) Self {
            var mod = std.mem.zeroes(c.sapi_module_struct);

            // Module identity.
            mod.name = @constCast(options.name);
            mod.pretty_name = @constCast(options.pretty_name orelse options.name);

            // Lifecycle; PHP module startup/shutdown is managed by the host.
            mod.startup = null;
            mod.shutdown = null;
            mod.activate = activate;
            mod.deactivate = deactivate;

            // Response output and headers.
            mod.ub_write = ubWrite;
            mod.flush = if (options.flush != null) Self.flush else null;
            mod.send_headers = @This().sendHeaders;

            // Request input and server variables.
            mod.read_post = readPost;
            // sapi_activate calls read_cookies without checking for null.
            mod.read_cookies = readCookies;
            mod.register_server_variables = registerServerVariables;
            mod.default_post_reader = c.php_default_post_reader;
            mod.treat_data = c.php_default_treat_data;
            mod.input_filter = c.php_default_input_filter;

            // Error reporting and logging.
            mod.sapi_error = c.php_error;
            mod.log_message = logMessage;

            // INI configuration and phpinfo output.
            mod.php_ini_ignore = @intFromBool(config.ini_ignore);
            mod.php_ini_ignore_cwd = @intFromBool(config.ini_ignore_cwd);
            mod.phpinfo_as_text = @backingInt(config.info_format);

            c.sapi_startup(&mod);
            // sapi_startup clears ini_entries; install it before PHP module startup.
            mod.ini_entries = if (config.ini_entries) |text| @constCast(text.ptr) else null;
            return .{ .entry = mod };
        }

        /// Release SAPI state after PHP module shutdown. Does not free this instance.
        pub fn deinit(self: *Self) void {
            _ = self;
            c.sapi_shutdown();
        }

        /// Start the PHP engine and its modules.
        /// Borrow the optional module entry through PHP module shutdown.
        /// Call shutdown only after success; a failed startup is not safely retryable.
        pub fn startup(self: *Self, additional_module: ?*ModuleEntry) error{ModuleStartupFailed}!void {
            if (c.php_module_startup(self.ptr(), additional_module) != c.SUCCESS)
                return error.ModuleStartupFailed;
        }

        /// Shut down the PHP engine and its modules.
        /// Finish all requests and worker threads first, then call deinit().
        pub fn shutdown(self: *Self) void {
            _ = self;
            c.php_module_shutdown();
        }

        /// Borrow this instance's module table; configure it before startup().
        /// Do not move the instance while holding this pointer.
        pub inline fn ptr(self: *Self) *c.sapi_module_struct {
            return &self.entry;
        }

        /// Bind after PHP module startup, before request startup on the current thread.
        /// Keep the backend alive and bound through request shutdown, then clear it.
        pub fn setContext(request_context: ?*T) void {
            globals.sapi().ptr().server_context = request_context;
        }

        /// SG(server_context) must be null or point to this SAPI's T.
        pub fn context() ?*T {
            return @ptrCast(@alignCast(globals.sapi().ptr().server_context));
        }

        fn ubWrite(bytes: [*c]const u8, len: usize) callconv(.c) usize {
            const backend = context() orelse return 0;
            options.ub_write(backend, bytes[0..len]) catch |err| {
                report("ub_write", err);
                c.php_handle_aborted_connection();
                return 0;
            };
            return len;
        }

        fn flush(server_context: ?*anyopaque) callconv(.c) void {
            const backend: *T = @ptrCast(@alignCast(server_context orelse return));
            if (comptime options.flush != null) {
                options.flush.?(backend) catch |err| {
                    report("flush", err);
                    c.php_handle_aborted_connection();
                };
            }
        }

        fn sendHeaders(headers: [*c]c.sapi_headers_struct) callconv(.c) c_int {
            const backend = context() orelse return c.SAPI_HEADER_SENT_SUCCESSFULLY;
            if (comptime options.send_headers != null) {
                options.send_headers.?(backend, Headers.from(headers)) catch |err| {
                    report("send_headers", err);
                    return c.SAPI_HEADER_SEND_FAILED;
                };
            }
            return c.SAPI_HEADER_SENT_SUCCESSFULLY;
        }

        fn readPost(bytes: [*c]u8, len: usize) callconv(.c) usize {
            const backend = context() orelse return 0;
            if (comptime options.read_post != null) {
                const size = options.read_post.?(backend, bytes[0..len]) catch |err| {
                    report("read_post", err);
                    bailout.raise();
                };
                if (size > len) {
                    report("read_post", error.InvalidReadLength);
                    bailout.raise();
                }
                return size;
            }
            return 0;
        }

        fn readCookies() callconv(.c) [*c]u8 {
            const backend = context() orelse return null;
            if (comptime options.read_cookies != null) {
                const cookie = options.read_cookies.?(backend) catch |err| {
                    report("read_cookies", err);
                    bailout.raise();
                };
                return if (cookie) |value| value.ptr else null;
            }
            return null;
        }

        fn activate() callconv(.c) c_int {
            const backend = context() orelse return c.SUCCESS;
            if (comptime options.activate != null) {
                options.activate.?(backend) catch |err| {
                    report("activate", err);
                    bailout.raise(); // PHP ignores the return value.
                };
            }
            return c.SUCCESS;
        }

        fn deactivate() callconv(.c) c_int {
            const backend = context() orelse return c.SUCCESS;
            if (comptime options.deactivate != null) {
                options.deactivate.?(backend) catch |err| report("deactivate", err);
            }
            return c.SUCCESS;
        }

        fn registerServerVariables(array: [*c]c.zval) callconv(.c) void {
            const backend = context() orelse return;
            if (comptime options.register_server_variables != null) {
                options.register_server_variables.?(backend, ServerVars.from(array)) catch |err| {
                    report("register_server_variables", err);
                    bailout.raise();
                };
            }
        }

        fn logMessage(message: [*c]const u8, level: c_int) callconv(.c) void {
            log(if (message == null) "" else std.mem.span(message), @intCast(level));
        }

        fn log(bytes: []const u8, level: i32) void {
            if (comptime options.log_message != null) {
                if (context()) |backend| {
                    options.log_message.?(backend, bytes, level);
                    return;
                }
            }
            std.log.err("{s}", .{bytes});
        }

        fn report(comptime callback: []const u8, err: anyerror) void {
            var buffer: [256]u8 = undefined;
            const message = std.fmt.bufPrint(&buffer, "SAPI {s}: {s}", .{ callback, @errorName(err) }) catch @errorName(err);
            log(message, -1);
        }
    };
}

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(InfoFormat);
    std.testing.refAllDecls(request);
    std.testing.refAllDecls(Globals);
    std.testing.refAllDecls(Headers);
    std.testing.refAllDecls(RequestInfo);
    std.testing.refAllDecls(ServerVars);
    const Backend = struct {
        fn write(_: *@This(), _: []const u8) !void {}
    };
    std.testing.refAllDecls(Sapi(Backend, .{ .name = "test_sapi", .ub_write = Backend.write }));
}
