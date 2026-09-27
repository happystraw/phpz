const phpz = @import("phpz");

pub fn objectProperties(object: *phpz.zend.Object, standard: bool) !*phpz.zend.Array {
    const props = if (standard) try object.stdProperties() else try object.properties();
    return if (props) |table| table.dupe() else phpz.zend.Array.empty();
}

pub fn hasObjectProperty(object: *phpz.zend.Object, name: []const u8, standard: bool) !bool {
    return if (standard)
        try object.hasStdProperty(name, .isset)
    else
        try object.hasProperty(name, .isset);
}

pub fn initObject(class_name: []const u8) !*phpz.zend.Object {
    const entry = (try phpz.ClassEntry.lookup(class_name, true)) orelse return error.ClassNotFound;
    return try phpz.zend.Object.init(entry);
}

pub fn cloneObject(object: *phpz.zend.Object) !*phpz.zend.Object {
    return try object.clone();
}

pub fn constructObject(class_name: []const u8, named: *phpz.zend.Array, guarded: bool) !*phpz.zend.Object {
    const entry = (try phpz.ClassEntry.lookup(class_name, true)) orelse return error.ClassNotFound;
    return if (guarded)
        try phpz.zend.Object.tryNew(entry, .{}, named)
    else
        try phpz.zend.Object.new(entry, .{}, named);
}
