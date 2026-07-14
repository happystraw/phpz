const std = @import("std");

const default_dllimport_data_symbols = [_][]const u8{
    "std_object_handlers",
    "zend_empty_array",
    "zend_empty_string",
    "zend_known_strings",
    "zend_new_interned_string",
    "zend_one_char_string",
    "zend_string_init_existing_interned",
    "zend_string_init_interned",

    // NTS
    "executor_globals",
    "compiler_globals",
    "core_globals",
    "sapi_globals",
    "file_globals",

    // ZTS
    "executor_globals_id",
    "compiler_globals_id",
    "core_globals_id",
    "sapi_globals_id",
    "file_globals_id",
    "executor_globals_offset",
    "compiler_globals_offset",
    "core_globals_offset",
    "sapi_globals_offset",
};

const default_dllimport_data_prefixes = [_][]const u8{
    "zend_ce_",
    "spl_ce_",
};

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    var args = try init.minimal.args.iterateAllocator(arena);

    const cmd = args.next() orelse "windows-patcher";
    const input_path = args.next() orelse fatal("usage: {s} <input.zig> <output.zig>", .{cmd});
    const output_path = args.next() orelse fatal("usage: {s} <input.zig> <output.zig>", .{cmd});
    if (args.next() != null) {
        fatal("usage: {s} <input.zig> <output.zig>", .{cmd});
    }

    const cwd = std.Io.Dir.cwd();
    const source = try cwd.readFileAllocOptions(init.io, input_path, arena, .unlimited, .of(u8), 0);

    var result = std.ArrayList(u8).empty;

    try patch(arena, &result, source, .{
        .dllimport_data_symbols = &default_dllimport_data_symbols,
        .dllimport_data_prefixes = &default_dllimport_data_prefixes,
    });
    try cwd.writeFile(init.io, .{ .sub_path = output_path, .data = result.items });
}

fn patch(
    gpa: std.mem.Allocator,
    result: *std.ArrayList(u8),
    source: [:0]const u8,
    options: Patcher.Options,
) !void {
    var tree = try std.zig.Ast.parse(gpa, source, .{ .mode = .zig });
    defer tree.deinit(gpa);

    if (tree.errors.len != 0) {
        const parse_error = tree.errors[0];
        const loc = tree.tokenLocation(0, parse_error.token);
        fatal("unable to parse translated Zig at {d}:{d}", .{ loc.line + 1, loc.column + 1 });
    }

    var patcher = Patcher.init(gpa, tree);
    defer patcher.deinit();

    const changed = try patcher.patch(options);
    if (!changed) {
        try result.appendSlice(gpa, source);
        return;
    }

    try patcher.render(result);
}

const Patcher = struct {
    gpa: std.mem.Allocator,
    tree: std.zig.Ast,
    fixups: std.zig.Ast.Render.Fixups = .{},
    dllimport_data_symbols: std.StringHashMapUnmanaged(DllImportDataSymbol) = .empty,
    allocated_replacements: std.ArrayList([]u8) = .empty,

    const Options = struct {
        dllimport_data_symbols: []const []const u8 = &.{},
        dllimport_data_prefixes: []const []const u8 = &.{},
    };

    const DllImportDataSymbol = struct {
        name: []const u8,
        type_expr: []const u8,
        is_const: bool,
    };

    const TokenRange = struct { first: std.zig.Ast.TokenIndex, last: std.zig.Ast.TokenIndex };

    fn init(gpa: std.mem.Allocator, tree: std.zig.Ast) Patcher {
        return .{ .gpa = gpa, .tree = tree };
    }

    fn deinit(self: *Patcher) void {
        for (self.allocated_replacements.items) |replacement| {
            self.gpa.free(replacement);
        }
        self.allocated_replacements.deinit(self.gpa);
        self.dllimport_data_symbols.deinit(self.gpa);
        self.fixups.deinit(self.gpa);
    }

    fn patch(self: *Patcher, options: Options) !bool {
        try self.collectDllImportDataSymbols(options);
        return try self.patchDllImportDataReferences();
    }

    fn collectDllImportDataSymbols(self: *Patcher, options: Options) !void {
        for (self.tree.rootDecls()) |node| {
            const var_decl = self.tree.fullVarDecl(node) orelse continue;
            const extern_token = var_decl.extern_export_token orelse continue;
            if (self.tree.tokenTag(extern_token) != .keyword_extern) continue;
            if (var_decl.lib_name != null) continue;

            const name_token = var_decl.ast.mut_token + 1;
            if (self.tree.tokenTag(name_token) != .identifier) continue;

            const name = self.tree.tokenSlice(name_token);
            if (!isDllImportDataSymbolName(name, options)) continue;

            // pub extern var executor_globals: zend_executor_globals;
            // - name:      executor_globals
            // - type_expr: zend_executor_globals
            // - is_const:  false
            const type_node = var_decl.ast.type_node.unwrap() orelse continue;
            try self.dllimport_data_symbols.put(self.gpa, name, .{
                .name = name,
                .type_expr = self.tree.getNodeSource(type_node),
                .is_const = self.tree.tokenTag(var_decl.ast.mut_token) == .keyword_const,
            });
        }
    }

    fn patchDllImportDataReferences(self: *Patcher) !bool {
        if (self.dllimport_data_symbols.count() == 0) return false;

        var fn_body_ranges = std.ArrayList(TokenRange).empty;
        defer fn_body_ranges.deinit(self.gpa);
        try self.collectFunctionBodyRanges(&fn_body_ranges);
        if (fn_body_ranges.items.len == 0) return false;

        var addressed_identifiers: std.AutoHashMapUnmanaged(std.zig.Ast.Node.Index, void) = .empty;
        defer addressed_identifiers.deinit(self.gpa);

        var changed = false;
        for (0..self.tree.nodes.len) |node_i| {
            const node: std.zig.Ast.Node.Index = @enumFromInt(node_i);
            if (self.tree.nodeTag(node) != .address_of) continue;
            if (!self.nodeInTokenRanges(node, fn_body_ranges.items)) continue;

            const child = self.tree.nodeData(node).node;
            const symbol = self.identifierDllImportDataSymbol(child) orelse continue;

            // &executor_globals -> @extern(*zend_executor_globals, ...)
            const replacement = try self.dllImportPointerExpr(symbol);
            try self.fixups.replace_nodes_with_string.put(self.gpa, node, replacement);
            try addressed_identifiers.put(self.gpa, child, {});
            changed = true;
        }

        for (0..self.tree.nodes.len) |node_i| {
            const node: std.zig.Ast.Node.Index = @enumFromInt(node_i);
            if (self.tree.nodeTag(node) != .identifier) continue;
            // Its parent &identifier node already has a replacement; avoid overlapping fixups.
            if (addressed_identifiers.contains(node)) continue;
            if (!self.nodeInTokenRanges(node, fn_body_ranges.items)) continue;

            const symbol = self.identifierDllImportDataSymbol(node) orelse continue;

            // executor_globals -> (@extern(*zend_executor_globals, ...).*)
            const replacement = try self.dllImportValueExpr(symbol);
            try self.fixups.replace_nodes_with_string.put(self.gpa, node, replacement);
            changed = true;
        }

        return changed;
    }

    fn collectFunctionBodyRanges(
        self: *Patcher,
        ranges: *std.ArrayList(TokenRange),
    ) !void {
        for (self.tree.rootDecls()) |node| {
            if (self.tree.nodeTag(node) != .fn_decl) continue;
            const fn_parts = self.tree.nodeData(node).node_and_node;
            const body_node = fn_parts[1];
            try ranges.append(self.gpa, .{
                .first = self.tree.firstToken(body_node),
                .last = self.tree.lastToken(body_node),
            });
        }
    }

    fn identifierDllImportDataSymbol(
        self: *Patcher,
        node: std.zig.Ast.Node.Index,
    ) ?DllImportDataSymbol {
        if (self.tree.nodeTag(node) != .identifier) return null;
        const name = self.tree.tokenSlice(self.tree.nodeMainToken(node));
        return self.dllimport_data_symbols.get(name);
    }

    fn dllImportPointerExpr(self: *Patcher, symbol: DllImportDataSymbol) ![]const u8 {
        const const_kw = if (symbol.is_const) "const " else "";
        return self.allocReplacement(
            \\@extern(*{s}{s}, .{{ .name = "{s}", .is_dll_import = true }})
        , .{ const_kw, symbol.type_expr, symbol.name });
    }

    fn dllImportValueExpr(self: *Patcher, symbol: DllImportDataSymbol) ![]const u8 {
        const const_kw = if (symbol.is_const) "const " else "";
        return self.allocReplacement(
            \\(@extern(*{s}{s}, .{{ .name = "{s}", .is_dll_import = true }}).*)
        , .{ const_kw, symbol.type_expr, symbol.name });
    }

    fn allocReplacement(self: *Patcher, comptime fmt: []const u8, args: anytype) ![]const u8 {
        const replacement = try std.fmt.allocPrint(self.gpa, fmt, args);
        errdefer self.gpa.free(replacement);
        try self.allocated_replacements.append(self.gpa, replacement);
        return replacement;
    }

    fn render(self: *Patcher, result: *std.ArrayList(u8)) !void {
        var aw: std.Io.Writer.Allocating = .init(self.gpa);
        defer aw.deinit();

        try self.tree.render(self.gpa, &aw.writer, self.fixups);
        try result.appendSlice(self.gpa, aw.written());
    }

    fn nodeInTokenRanges(self: *const Patcher, node: std.zig.Ast.Node.Index, ranges: []const TokenRange) bool {
        const first_token = self.tree.firstToken(node);
        for (ranges) |range| {
            if (first_token >= range.first and first_token <= range.last) return true;
        }
        return false;
    }

    fn isDllImportDataSymbolName(name: []const u8, options: Options) bool {
        if (std.mem.startsWith(u8, name, "__imp_")) return false;
        if (std.mem.endsWith(u8, name, "_module_entry")) return false;

        for (options.dllimport_data_symbols) |symbol| {
            if (std.mem.eql(u8, name, symbol)) return true;
        }
        for (options.dllimport_data_prefixes) |prefix| {
            if (std.mem.startsWith(u8, name, prefix)) return true;
        }

        return false;
    }
};

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format ++ "\n", args);
    std.process.exit(1);
}

test "patches address-of dllimport data references in function bodies" {
    const raw_source =
        \\pub extern const std_object_handlers: zend_object_handlers;
        \\pub const untouched = &std_object_handlers;
        \\pub fn register() callconv(.c) void {
        \\    ce.default_object_handlers = &std_object_handlers;
        \\}
        \\
    ;
    const source = try std.testing.allocator.dupeSentinel(u8, raw_source, 0);
    defer std.testing.allocator.free(source);
    var result = std.ArrayList(u8).empty;
    defer result.deinit(std.testing.allocator);
    const dllimport_data_symbols = [_][]const u8{"std_object_handlers"};

    try patch(std.testing.allocator, &result, source, .{
        .dllimport_data_symbols = &dllimport_data_symbols,
    });

    try std.testing.expect(std.mem.indexOf(u8, result.items, "untouched = &std_object_handlers") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.items, "ce.default_object_handlers = @extern(*const zend_object_handlers, .{ .name = \"std_object_handlers\", .is_dll_import = true })") != null);
}

test "patches value dllimport data references in function bodies" {
    const raw_source =
        \\pub extern var zend_ce_exception: [*c]zend_class_entry;
        \\pub fn register() callconv(.c) void {
        \\    var class_entry = zend_ce_exception;
        \\    _ = class_entry;
        \\}
        \\
    ;
    const source = try std.testing.allocator.dupeSentinel(u8, raw_source, 0);
    defer std.testing.allocator.free(source);
    var result = std.ArrayList(u8).empty;
    defer result.deinit(std.testing.allocator);
    const dllimport_data_prefixes = [_][]const u8{"zend_ce_"};

    try patch(std.testing.allocator, &result, source, .{
        .dllimport_data_prefixes = &dllimport_data_prefixes,
    });

    try std.testing.expect(std.mem.indexOf(u8, result.items, "var class_entry = (@extern(*[*c]zend_class_entry, .{ .name = \"zend_ce_exception\", .is_dll_import = true }).*)") != null);
}

test "patches dllimport function pointer data calls in function bodies" {
    const raw_source =
        \\pub const zend_string_init_interned_func_t = ?*const fn (str: [*c]const u8, size: usize, permanent: bool) callconv(.c) [*c]zend_string;
        \\pub extern var zend_string_init_interned: zend_string_init_interned_func_t;
        \\pub fn register() callconv(.c) void {
        \\    ce.name = zend_string_init_interned.?("Example", 7, true);
        \\}
        \\
    ;
    const source = try std.testing.allocator.dupeSentinel(u8, raw_source, 0);
    defer std.testing.allocator.free(source);
    var result = std.ArrayList(u8).empty;
    defer result.deinit(std.testing.allocator);
    const dllimport_data_symbols = [_][]const u8{"zend_string_init_interned"};

    try patch(std.testing.allocator, &result, source, .{
        .dllimport_data_symbols = &dllimport_data_symbols,
    });

    try std.testing.expect(std.mem.indexOf(u8, result.items, "(@extern(*zend_string_init_interned_func_t, .{ .name = \"zend_string_init_interned\", .is_dll_import = true }).*).?(\"Example\", 7, true)") != null);
}
