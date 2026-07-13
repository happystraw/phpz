const std = @import("std");

const phpz = @import("phpz");

const Call = struct {
    const max_depth = 256;
    const max_functions = 64;
    const max_name_len = 192;
    const max_duration_samples = 64;

    total: u64 = 0,
    by_name: Metrics = .{},
    depth: usize = 0,
    frames: [max_depth]Frame = @splat(.{}),

    const Metric = struct {
        name_buffer: [max_name_len]u8 = @splat(0),
        name_len: usize = 0,
        kind: phpz.zend.Function.Kind = .internal,
        role: phpz.zend.Function.Role = .function,
        calls: u64 = 0,
        duration_ns: [max_duration_samples]u64 = @splat(0),
        duration_len: usize = 0,

        fn name(self: *const Metric) []const u8 {
            return self.name_buffer[0..self.name_len];
        }

        fn appendDuration(self: *Metric, duration_ns: u64) void {
            if (self.duration_len == self.duration_ns.len) return;
            self.duration_ns[self.duration_len] = duration_ns;
            self.duration_len += 1;
        }
    };

    const Metrics = struct {
        len: usize = 0,
        items: [max_functions]Metric = @splat(.{}),

        fn getOrAdd(
            self: *Metrics,
            name: []const u8,
            kind: phpz.zend.Function.Kind,
            role: phpz.zend.Function.Role,
        ) ?usize {
            for (self.items[0..self.len], 0..) |*item, index| {
                if (std.mem.eql(u8, item.name(), name)) return index;
            }
            if (self.len == self.items.len or name.len > max_name_len) return null;

            const index = self.len;
            self.len += 1;
            const item = &self.items[index];
            @memcpy(item.name_buffer[0..name.len], name);
            item.name_len = name.len;
            item.kind = kind;
            item.role = role;
            return index;
        }
    };

    const Frame = struct {
        started_at: u64 = 0,
        function_index: ?usize = null,
    };

    fn writeName(function: *phpz.zend.Function, buffer: []u8) ?[]const u8 {
        const name = function.name();
        if (function.ptr().*.common.scope) |scope| {
            const class_name = phpz.zend.ClassEntry.from(scope).name();
            const len = class_name.len + 2 + name.len;
            if (len > buffer.len) return null;
            @memcpy(buffer[0..class_name.len], class_name);
            @memcpy(buffer[class_name.len .. class_name.len + 2], "::");
            @memcpy(buffer[class_name.len + 2 .. len], name);
            return buffer[0..len];
        }
        if (name.len > buffer.len) return null;
        @memcpy(buffer[0..name.len], name);
        return buffer[0..name.len];
    }

    fn filter(function: *phpz.zend.Function) bool {
        if (function.ptr().*.common.scope) |scope| {
            const class_name = phpz.zend.ClassEntry.from(scope).name();
            if (std.mem.eql(u8, class_name, "MyPHPExt\\Metrics")) return false;
        }
        return !std.mem.eql(u8, function.name(), "MyPHPExt\\Test\\allocatorBailout");
    }

    fn begin(call: *phpz.Ctx.Call) void {
        const function = call.function() orelse return;
        const function_calls = &Globals.get().function_calls;
        function_calls.total += 1;

        var name_buffer: [max_name_len]u8 = undefined;
        const function_index = if (writeName(function, &name_buffer)) |name|
            function_calls.by_name.getOrAdd(name, function.kind(), function.role())
        else
            null;
        if (function_index) |index| function_calls.by_name.items[index].calls += 1;

        const current_depth = function_calls.depth;
        if (current_depth < function_calls.frames.len) {
            function_calls.frames[current_depth] = .{
                .started_at = now(),
                .function_index = function_index,
            };
        }
        function_calls.depth = current_depth + 1;
    }

    fn end(call: *phpz.Ctx.Call, retval: ?*phpz.Zval) void {
        _ = call;
        _ = retval;
        const function_calls = &Globals.get().function_calls;
        if (function_calls.depth == 0) return;

        function_calls.depth -= 1;
        const current_depth = function_calls.depth;
        if (current_depth < function_calls.frames.len) {
            const frame = function_calls.frames[current_depth];
            if (frame.function_index) |index| {
                function_calls.by_name.items[index].appendDuration(now() - frame.started_at);
            }
        }
    }

    fn write(self: *const Call, result: *phpz.Zval.Array) !void {
        var by_name_zv = phpz.Zval.raw.undef;
        var by_name = phpz.Zval.Array.empty(&by_name_zv);
        for (self.by_name.items[0..self.by_name.len]) |*function| {
            var function_zv = phpz.Zval.raw.undef;
            var item = phpz.Zval.Array.empty(&function_zv);
            item.set(.string, "kind", @tagName(function.kind));
            item.set(.string, "role", @tagName(function.role));
            item.set(.int, "calls", phpInt(function.calls));

            var duration_ns_zv = phpz.Zval.raw.undef;
            var duration_ns = phpz.Zval.Array.empty(&duration_ns_zv);
            for (function.duration_ns[0..function.duration_len]) |duration| {
                try duration_ns.append(.int, phpInt(duration));
            }
            item.set(.mixed, "duration_ns", &duration_ns_zv);
            by_name.set(.mixed, function.name(), &function_zv);
        }

        var function_calls_zv = phpz.Zval.raw.undef;
        var function_calls = phpz.Zval.Array.empty(&function_calls_zv);
        function_calls.set(.int, "total", phpInt(self.total));
        function_calls.set(.mixed, "by_name", &by_name_zv);
        result.set(.mixed, "function_calls", &function_calls_zv);
    }
};

const Error = struct {
    const c = phpz.c;

    total: u64 = 0,
    warnings: u64 = 0,

    fn observe(info: phpz.observer.Error.Info) void {
        const errors = &Globals.get().errors;
        errors.total += 1;
        if (info.level.matches(c.E_WARNING | c.E_CORE_WARNING | c.E_COMPILE_WARNING | c.E_USER_WARNING)) {
            errors.warnings += 1;
        }
    }

    fn write(self: *const Error, result: *phpz.Zval.Array) void {
        var errors_zv = phpz.Zval.raw.undef;
        var errors = phpz.Zval.Array.empty(&errors_zv);
        errors.set(.int, "total", phpInt(self.total));
        errors.set(.int, "warnings", phpInt(self.warnings));
        result.set(.mixed, "errors", &errors_zv);
    }
};

const Exception = struct {
    const max_classes = 32;
    const max_name_len = 128;

    total: u64 = 0,
    by_class: Classes = .{},

    const Class = struct {
        name_buffer: [max_name_len]u8 = @splat(0),
        name_len: usize = 0,
        count: u64 = 0,

        fn name(self: *const Class) []const u8 {
            return self.name_buffer[0..self.name_len];
        }
    };

    const Classes = struct {
        len: usize = 0,
        items: [max_classes]Class = @splat(.{}),

        fn increment(self: *Classes, name: []const u8) void {
            for (self.items[0..self.len]) |*item| {
                if (std.mem.eql(u8, item.name(), name)) {
                    item.count += 1;
                    return;
                }
            }
            if (self.len == self.items.len or name.len > max_name_len) return;

            const item = &self.items[self.len];
            self.len += 1;
            @memcpy(item.name_buffer[0..name.len], name);
            item.name_len = name.len;
            item.count = 1;
        }
    };

    fn observe(exception: *phpz.zend.Object) void {
        const exceptions = &Globals.get().exceptions;
        exceptions.total += 1;
        exceptions.by_class.increment(exception.class().name());
    }

    fn write(self: *const Exception, result: *phpz.Zval.Array) void {
        var by_class_zv = phpz.Zval.raw.undef;
        var by_class = phpz.Zval.Array.empty(&by_class_zv);
        for (self.by_class.items[0..self.by_class.len]) |*class| {
            by_class.set(.int, class.name(), phpInt(class.count));
        }

        var exceptions_zv = phpz.Zval.raw.undef;
        var exceptions = phpz.Zval.Array.empty(&exceptions_zv);
        exceptions.set(.int, "total", phpInt(self.total));
        exceptions.set(.mixed, "by_class", &by_class_zv);
        result.set(.mixed, "exceptions", &exceptions_zv);
    }
};

const Request = struct {
    function_calls: Call = .{},
    errors: Error = .{},
    exceptions: Exception = .{},
};

pub const Globals = phpz.ModuleGlobals(Request);

fn now() u64 {
    const io = std.Io.Threaded.global_single_threaded.io();
    return @intCast(std.Io.Clock.awake.now(io).nanoseconds);
}

fn phpInt(value: anytype) i64 {
    return @intCast(@min(value, std.math.maxInt(i64)));
}

pub const observer: phpz.observer.Config = .{
    .fcall = .{
        .filter = Call.filter,
        .begin = Call.begin,
        .end = Call.end,
    },
    .errors = .{
        .observe = Error.observe,
    },
    .exception = .{
        .observe = Exception.observe,
    },
};

pub fn reset() void {
    Globals.get().* = .{};
}

pub fn requestStartup() !void {
    reset();
}

pub fn writeSnapshot(ctx: phpz.Ctx) !void {
    const request = Globals.get();
    const result = phpz.Zval.Array.empty(ctx.ret.ptr());
    try request.function_calls.write(result);
    request.errors.write(result);
    request.exceptions.write(result);
}
