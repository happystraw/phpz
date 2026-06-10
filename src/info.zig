const c = @import("root.zig").c;

/// HTML table helpers for phpinfo() output.
///
/// Usage:
/// ```zig
/// fn info(_: *phpz.ModuleEntry) void {
///     phpz.info.table.start();
///     phpz.info.table.row(.{ "MyExtension support", "enabled" });
///     phpz.info.table.row(.{ "Version", "1.0.0" });
///     phpz.info.table.end();
/// }
/// ```
pub const table = struct {
    pub fn start() void {
        c.php_info_print_table_start();
    }

    pub fn end() void {
        c.php_info_print_table_end();
    }

    /// Add a header row. Accepts a tuple of strings (any arity).
    pub fn header(fields: anytype) void {
        comptime assertTuple(@TypeOf(fields));
        @call(.auto, c.php_info_print_table_header, .{fields.len} ++ fields);
    }

    /// Add a data row. Accepts a tuple of strings (any arity).
    pub fn row(fields: anytype) void {
        comptime assertTuple(@TypeOf(fields));
        @call(.auto, c.php_info_print_table_row, .{fields.len} ++ fields);
    }

    /// Add a data row with an explicit CSS class for the first cell.
    pub fn rowEx(class: [*:0]const u8, fields: anytype) void {
        comptime assertTuple(@TypeOf(fields));
        @call(.auto, c.php_info_print_table_row_ex, .{fields.len} ++ .{class} ++ fields);
    }

    /// Add a heading row spanning `num_cols` columns (section heading).
    pub fn colspanHeader(comptime num_cols: comptime_int, title: [*:0]const u8) void {
        c.php_info_print_table_colspan_header(num_cols, title);
    }

    /// Convenience: print an INI-style row (Directive | Local | Master).
    pub fn iniRow(name: [*:0]const u8, local_value: [*:0]const u8, master_value: [*:0]const u8) void {
        row(.{ name, local_value, master_value });
    }
};

fn assertTuple(comptime T: type) void {
    const info = @typeInfo(T);
    if (info != .@"struct" or !info.@"struct".is_tuple) {
        @compileError("expected a tuple, e.g. .{ \"col1\", \"col2\" }, got " ++ @typeName(T));
    }
}
test {
    const std = @import("std");
    std.testing.refAllDecls(table);
}
