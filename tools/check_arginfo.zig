const std = @import("std");

const regeneration_hint = "\n\nRun 'zig build gen-stub' to regenerate the arginfo header.";
const usage_hint = "\nUsage: {s} <stub.php> <arginfo.h>";

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    var args = try init.minimal.args.iterateAllocator(arena);

    const cmd = args.next() orelse "check-arginfo";
    const stub_path = args.next() orelse fatal("missing PHP stub file path" ++ usage_hint, .{cmd});
    const arginfo_path = args.next() orelse fatal("missing arginfo header path" ++ usage_hint, .{cmd});
    if (args.next()) |extra| {
        fatal("unexpected argument: {s}" ++ usage_hint, .{ extra, cmd });
    }

    const cwd = std.Io.Dir.cwd();
    const stub = cwd.readFileAllocOptions(init.io, stub_path, arena, .unlimited, .of(u8), 0) catch |err| {
        fatal("cannot read PHP stub file {s}: {s}", .{ stub_path, @errorName(err) });
    };
    const arginfo = cwd.readFileAllocOptions(init.io, arginfo_path, arena, .unlimited, .of(u8), 0) catch |err| {
        fatal("cannot read arginfo header {s}: {s}", .{ arginfo_path, @errorName(err) });
    };

    const expected = computeStubHash(stub);
    const actual = parseArginfoHash(arginfo) catch |err| switch (err) {
        error.MissingStubHash => fatal("missing stub hash in {s}" ++ regeneration_hint, .{arginfo_path}),
        error.InvalidStubHash => fatal("invalid stub hash in {s}" ++ regeneration_hint, .{arginfo_path}),
    };
    if (!std.mem.eql(u8, &expected, actual)) {
        fatal(
            "stub hash mismatch between {s} and {s}\n  Expected: {s}\n  Found:    {s}" ++ regeneration_hint ++ "\nTo skip this check, set check_arginfo = false in the Phpz options.",
            .{ arginfo_path, stub_path, &expected, actual },
        );
    }
}

const stub_hash_length = std.crypto.hash.Sha1.digest_length * 2;

fn computeStubHash(stub: []const u8) [stub_hash_length]u8 {
    var sha1 = std.crypto.hash.Sha1.init(.{});
    var offset: usize = 0;
    while (std.mem.indexOfPos(u8, stub, offset, "\r\n")) |index| {
        sha1.update(stub[offset..index]);
        sha1.update("\n");
        offset = index + 2;
    }
    sha1.update(stub[offset..]);

    var digest: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
    sha1.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

const ParseArginfoHashError = error{
    MissingStubHash,
    InvalidStubHash,
};

fn parseArginfoHash(arginfo: []const u8) ParseArginfoHashError![]const u8 {
    const marker = "* Stub hash: ";
    const marker_index = std.mem.indexOf(u8, arginfo, marker) orelse return error.MissingStubHash;
    const hash_index = marker_index + marker.len;
    if (hash_index + stub_hash_length + " */".len > arginfo.len or
        !std.mem.eql(u8, arginfo[hash_index + stub_hash_length ..][0.." */".len], " */"))
    {
        return error.InvalidStubHash;
    }
    return arginfo[hash_index..][0..stub_hash_length];
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.process.exit(1);
}

test "computeStubHash computes the normalized SHA-1 hash" {
    const actual = computeStubHash("hello\n");
    try std.testing.expectEqualStrings("f572d396fae9206628714fb2ce00f72e94f2258f", actual[0..]);
}

test "computeStubHash normalizes CRLF line endings" {
    const lf = computeStubHash("first\nsecond\n");
    const crlf = computeStubHash("first\r\nsecond\r\n");
    try std.testing.expectEqual(lf, crlf);
}

test "parseArginfoHash extracts the generated stub hash" {
    const expected = "d84374eb3cc93ebb1e1cf6f0dfa2ee49381bec07";
    const arginfo = "/* Stub hash: " ++ expected ++ " */";
    try std.testing.expectEqualStrings(expected, try parseArginfoHash(arginfo));
}

test "parseArginfoHash rejects a missing stub hash" {
    try std.testing.expectError(error.MissingStubHash, parseArginfoHash("/* generated */"));
}

test "parseArginfoHash rejects a malformed stub hash" {
    try std.testing.expectError(error.InvalidStubHash, parseArginfoHash("/* Stub hash: short */"));
}
