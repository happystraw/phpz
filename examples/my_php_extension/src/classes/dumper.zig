const phpz = @import("phpz");
const c = phpz.c;
const std = @import("std");

pub const Dumper = extern struct {
    pub fn dump(ctx: phpz.Ctx) !void {
        for (ctx.call.args()) |*zv| {
            dumpValue(.from(zv), 0);
        }
    }

    fn dumpValue(val: *phpz.Zval, depth: usize) void {
        switch (val.kind()) {
            .null => {
                indent(depth);
                _ = phpz.printf("NULL\n", .{});
            },
            .bool => {
                indent(depth);
                _ = phpz.printf("bool(%s)\n", .{@as([*:0]const u8, if (val.asUnchecked(.bool)) "true" else "false")});
            },
            .int => {
                indent(depth);
                _ = phpz.printf("int(%ld)\n", .{val.asUnchecked(.int)});
            },
            .float => {
                indent(depth);
                _ = phpz.printf("float(%f)\n", .{val.asUnchecked(.float)});
            },
            .string => {
                indent(depth);
                const s = val.asUnchecked(.string);
                _ = phpz.printf("string(%d) \"%.*s\"\n", .{ s.len, s.len, s.ptr });
            },
            .array => {
                const zarr = phpz.zend.Array.from(val.asUnchecked(.array));
                indent(depth);
                _ = phpz.printf("array(%d) {\n", .{zarr.len()});
                var it = zarr.iterator();
                while (it.next()) |entry| {
                    indent(depth + 1);
                    switch (entry.key) {
                        .int => |n| _ = phpz.printf("[%ld] =>\n", .{n}),
                        .string => |s| _ = phpz.printf("[\"%.*s\"] =>\n", .{ s.len, s.ptr }),
                    }
                    dumpValue(.from(entry.value), depth + 1);
                }
                indent(depth);
                _ = phpz.printf("}\n", .{});
            },
            .reference => {
                indent(depth);
                _ = phpz.printf("&", .{});
                const ref = val.asUnchecked(.reference);
                dumpValue(.from(&ref.val), 0);
            },
            .resource => {
                indent(depth);
                const r = val.asUnchecked(.resource);
                _ = phpz.printf("resource(%d)\n", .{r.*.handle});
            },
            .object => {
                const obj = phpz.zend.Object.from(val.asUnchecked(.object));
                indent(depth);

                // Check if this is an enum
                if (obj.class().isEnum()) {
                    const case_name = obj.enumCaseName();
                    switch (obj.class().enumBackingType()) {
                        .int => {
                            const v = phpz.Zval.native.asUnchecked(obj.enumCaseValue().?, .int);
                            _ = phpz.printf("enum %.*s { %.*s = %ld }\n", .{
                                obj.class().name().len, obj.class().name().ptr,
                                case_name.len,          case_name.ptr,
                                v,
                            });
                        },
                        .string => {
                            const v = phpz.Zval.native.asUnchecked(obj.enumCaseValue().?, .string);
                            _ = phpz.printf("enum %.*s { %.*s = \"%.*s\" }\n", .{
                                obj.class().name().len, obj.class().name().ptr,
                                case_name.len,          case_name.ptr,
                                v.len,                  v.ptr,
                            });
                        },
                        else => {
                            _ = phpz.printf("enum %.*s { %.*s }\n", .{
                                obj.class().name().len, obj.class().name().ptr,
                                case_name.len,          case_name.ptr,
                            });
                        },
                    }
                    return;
                }

                const class_name = obj.class().name();
                const prop_count = obj.propertyCount();
                indent(depth);
                _ = phpz.printf("class %.*s#%d (%d) {\n", .{ class_name.len, class_name.ptr, obj.handle(), prop_count });
                if (obj.properties()) |props| {
                    var it = props.iterator();
                    while (it.next()) |entry| {
                        indent(depth + 1);
                        printPropertyVisibility(entry.key.string);
                        _ = phpz.printf(" =>\n", .{});
                        const prop = phpz.Zval.from(entry.value);
                        const real = if (prop.is(.indirect)) prop.asUnchecked(.indirect) else entry.value;
                        dumpValue(.from(real), depth + 1);
                    }
                }
                indent(depth);
                _ = phpz.printf("}\n", .{});
            },
            else => {
                indent(depth);
                _ = phpz.printf("<unhandled %s>\n", .{@tagName(val.kind()).ptr});
            },
        }
    }

    fn indent(depth: usize) void {
        var i: usize = 0;
        while (i < depth) : (i += 1) {
            _ = phpz.printf("  ", .{});
        }
    }

    fn printPropertyVisibility(raw: []const u8) void {
        if (raw.len > 0 and raw[0] == 0) {
            // \0 * \0 name  ->  protected $name
            if (raw.len > 2 and raw[1] == '*') {
                const name = raw[3..];
                _ = phpz.printf("protected $%.*s", .{ name.len, name.ptr });
                return;
            }
            // \0 ClassName \0 name  ->  private $name
            if (std.mem.lastIndexOfScalar(u8, raw, 0)) |last| {
                const name = raw[last + 1 ..];
                _ = phpz.printf("private $%.*s", .{ name.len, name.ptr });
                return;
            }
        }
        // public $name
        _ = phpz.printf("public $%.*s", .{ raw.len, raw.ptr });
    }
};

pub const Class = phpz.Class("MyPHPExt\\Dumper", Dumper);

comptime {
    Class.method("dump", .dump);
}
