const phpz = @import("phpz");

/// PHP: MyPHPExt\Dumper::dump(mixed ...$values): void
pub fn dump(args: phpz.Variadic) !void {
    try args.check(.positional_only);
    for (args.positional) |*zv| {
        try dumpValue(.from(zv), 0);
    }
}

fn dumpValue(value: *phpz.Zval, depth: usize) phpz.exception.Error!void {
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
                    .str => |key| {
                        const name = key.slice();
                        _ = phpz.printf("[\"%.*s\"] =>\n", .{ name.len, name.ptr });
                    },
                }
                try dumpValue(.from(entry.value), depth + 1);
            }

            indent(depth);
            _ = phpz.printf("}\n", .{});
        },
        .reference => {
            indent(depth);
            _ = phpz.printf("&", .{});
            try dumpValue(.from(value.asUnchecked(.reference).val()), 0);
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
            const properties = try object.properties();
            indent(depth);
            _ = phpz.printf("class %.*s#%d (%d) {\n", .{
                class_name.len,
                class_name.ptr,
                object.handle(),
                if (properties) |props| props.len() else 0,
            });

            if (properties) |props| {
                var iterator = props.fastIterator();
                while (iterator.next()) |entry| {
                    indent(depth + 1);
                    switch (entry.key) {
                        .int => |index| _ = phpz.printf("[%ld]", .{index}),
                        .str => |name| printPropertyVisibility(name),
                    }
                    _ = phpz.printf(" =>\n", .{});

                    const property = phpz.Zval.from(entry.value);
                    const raw = if (property.is(.indirect))
                        property.asUnchecked(.indirect)
                    else
                        entry.value;
                    try dumpValue(.from(raw), depth + 1);
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

fn printPropertyVisibility(key: *phpz.zend.String) void {
    const property = phpz.zend.property_name.unmangle(key) orelse {
        const raw = key.slice();
        _ = phpz.printf("public $%.*s", .{ raw.len, raw.ptr });
        return;
    };
    const visibility: [:0]const u8 = switch (property.scope) {
        .public => "public",
        .protected => "protected",
        .private => "private",
    };
    _ = phpz.printf("%s $%.*s", .{ visibility.ptr, property.name.len, property.name.ptr });
}

pub const Class = phpz.ClassDecl("MyPHPExt\\Dumper", .{
    .methods = .{ .dump = dump },
});
