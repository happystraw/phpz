const std = @import("std");

const phpz = @import("phpz");

/// PHP: MyPHPExt\Dumper::dump(mixed ...$values): void
pub fn dump(ctx: phpz.Ctx) !void {
    for (ctx.call.args()) |*zv| {
        dumpValue(.from(zv), 0);
    }
}

fn dumpValue(value: *phpz.Zval, depth: usize) void {
    switch (value.kind()) {
        .null => {
            indent(depth);
            _ = phpz.printf("NULL\n", .{});
        },
        .bool => {
            indent(depth);
            const text: [*:0]const u8 = if (value.asUnchecked(.bool)) "true" else "false";
            _ = phpz.printf("bool(%s)\n", .{text});
        },
        .int => {
            indent(depth);
            _ = phpz.printf("int(%ld)\n", .{value.asUnchecked(.int)});
        },
        .float => {
            indent(depth);
            _ = phpz.printf("float(%f)\n", .{value.asUnchecked(.float)});
        },
        .string => {
            indent(depth);
            const text = value.asUnchecked(.string);
            _ = phpz.printf("string(%d) \"%.*s\"\n", .{
                text.len,
                text.len,
                text.ptr,
            });
        },
        .array => {
            const array = value.asUnchecked(.array);
            indent(depth);
            _ = phpz.printf("array(%d) {\n", .{array.len()});

            var iterator = array.fastIterator();
            while (iterator.next()) |entry| {
                indent(depth + 1);
                switch (entry.key) {
                    .int => |index| _ = phpz.printf("[%ld] =>\n", .{index}),
                    .string => |key| _ = phpz.printf("[\"%.*s\"] =>\n", .{
                        key.len,
                        key.ptr,
                    }),
                }
                dumpValue(.from(entry.value), depth + 1);
            }

            indent(depth);
            _ = phpz.printf("}\n", .{});
        },
        .reference => {
            indent(depth);
            _ = phpz.printf("&", .{});
            dumpValue(.from(value.asUnchecked(.reference).val()), 0);
        },
        .resource => {
            indent(depth);
            _ = phpz.printf("resource(%d)\n", .{value.asUnchecked(.resource).handle()});
        },
        .object => {
            const object = value.asUnchecked(.object);
            if (object.isEnum()) {
                indent(depth);
                dumpEnum(object);
                return;
            }

            const class_name = object.class().name();
            indent(depth);
            _ = phpz.printf("class %.*s#%d (%d) {\n", .{
                class_name.len,
                class_name.ptr,
                object.handle(),
                object.propertyCount(),
            });

            if (object.properties()) |properties| {
                var iterator = properties.fastIterator();
                while (iterator.next()) |entry| {
                    indent(depth + 1);
                    printPropertyVisibility(entry.key.string);
                    _ = phpz.printf(" =>\n", .{});

                    const property = phpz.Zval.from(entry.value);
                    const raw = if (property.is(.indirect))
                        property.asUnchecked(.indirect)
                    else
                        entry.value;
                    dumpValue(.from(raw), depth + 1);
                }
            }

            indent(depth);
            _ = phpz.printf("}\n", .{});
        },
        else => {
            indent(depth);
            _ = phpz.printf("<unhandled %s>\n", .{@tagName(value.kind()).ptr});
        },
    }
}

fn dumpEnum(object: *phpz.zend.Object) void {
    const class_name = object.class().name();
    const case_name = object.enumCaseName();

    switch (object.enumBackingType()) {
        .int => {
            const raw = object.enumCaseValue().?;
            const backing = phpz.Zval.raw.asUnchecked(raw, .int);
            _ = phpz.printf("enum %.*s { %.*s = %ld }\n", .{
                class_name.len,
                class_name.ptr,
                case_name.len,
                case_name.ptr,
                backing,
            });
        },
        .string => {
            const raw = object.enumCaseValue().?;
            const backing = phpz.Zval.raw.asUnchecked(raw, .string);
            _ = phpz.printf("enum %.*s { %.*s = \"%.*s\" }\n", .{
                class_name.len,
                class_name.ptr,
                case_name.len,
                case_name.ptr,
                backing.len,
                backing.ptr,
            });
        },
        else => {
            _ = phpz.printf("enum %.*s { %.*s }\n", .{
                class_name.len,
                class_name.ptr,
                case_name.len,
                case_name.ptr,
            });
        },
    }
}

fn indent(depth: usize) void {
    for (0..depth) |_| {
        _ = phpz.printf("  ", .{});
    }
}

fn printPropertyVisibility(raw: []const u8) void {
    if (raw.len > 0 and raw[0] == 0) {
        if (raw.len > 2 and raw[1] == '*') {
            const name = raw[3..];
            _ = phpz.printf("protected $%.*s", .{ name.len, name.ptr });
            return;
        }

        if (std.mem.lastIndexOfScalar(u8, raw, 0)) |last| {
            const name = raw[last + 1 ..];
            _ = phpz.printf("private $%.*s", .{ name.len, name.ptr });
            return;
        }
    }

    _ = phpz.printf("public $%.*s", .{ raw.len, raw.ptr });
}

pub const Class = phpz.ClassDecl("MyPHPExt\\Dumper", .{
    .methods = .{ .dump = dump },
});
