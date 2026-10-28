const phpz = @import("phpz");
const extension = @import("extension_info");

const api = @import("api.zig");
const functions = @import("functions.zig");
const ini = @import("ini.zig");
const metrics = @import("metrics.zig");
const bailout = @import("testing/bailout.zig");
const guard_tests = @import("testing/guard.zig");
const superglobals = @import("testing/superglobals.zig");
const reference_arguments = @import("testing/reference_arguments.zig");
const references = @import("testing/references.zig");
const named_arguments = @import("testing/named_arguments.zig");
const closure_tests = @import("testing/closures.zig");
const gc = @import("testing/gc.zig");
const serialization = @import("testing/serialization.zig");
const class_new = @import("testing/class_new.zig");
const stream_tests = @import("testing/streams.zig");
const closures = @import("closures.zig");

const thread_tests = @import("testing/threads.zig");
const typed_arguments = @import("testing/typed_arguments.zig");
const argument_declaration = @import("testing/argument_declaration.zig");
const object_tests = @import("testing/objects.zig");
const object_access = @import("testing/object_access.zig");
const string_tests = @import("testing/strings.zig");
const array_tests = @import("testing/arrays.zig");
const iteration = @import("testing/iteration.zig");
const error_tests = @import("testing/errors.zig");
const exception_boundaries = @import("testing/exception_boundaries.zig");
const boundaries = @import("testing/boundaries.zig");
const class_entry = @import("testing/class_entry.zig");
const property_tests = @import("testing/properties.zig");
const zval_tests = @import("testing/zval.zig");

fn info(m: *phpz.ModuleEntry) void {
    phpz.info.table.start();
    phpz.info.table.header(.{ "my_php_extension support", "enabled" });
    phpz.info.table.row(.{ "version", m.version });
    phpz.info.table.end();
}

comptime {
    phpz.namedFunctions(.{
        .@"MyPHPExt\\Test\\checkArgumentDeclaration" = argument_declaration.checkArgumentDeclaration,
        .@"MyPHPExt\\Test\\readLastError" = error_tests.readLastError,
        .@"MyPHPExt\\Test\\checkExceptionBoundary" = exception_boundaries.checkExceptionBoundary,
        .@"MyPHPExt\\Test\\checkNativeTsrmThreads" = thread_tests.checkNativeTsrmThreads,
        .@"MyPHPExt\\Test\\checkStreams" = stream_tests.checkStreams,
        .@"MyPHPExt\\Test\\checkSocketOptions" = stream_tests.checkSocketOptions,
        .@"MyPHPExt\\Test\\openStream" = stream_tests.openStream,
        .@"MyPHPExt\\Test\\openPersistentStream" = stream_tests.openPersistentStream,
        .@"MyPHPExt\\Test\\checkPersistentStreams" = stream_tests.checkPersistentStreams,
        .@"MyPHPExt\\Test\\openStreamDir" = stream_tests.openStreamDir,
        .@"MyPHPExt\\Test\\readStreamDir" = stream_tests.readStreamDir,
        .@"MyPHPExt\\Test\\rewindStreamDir" = stream_tests.rewindStreamDir,
        .@"MyPHPExt\\Test\\readStream" = stream_tests.readStream,
        .@"MyPHPExt\\Test\\nullableStream" = stream_tests.nullableStream,
        .@"MyPHPExt\\Test\\optionalStream" = stream_tests.optionalStream,
        .@"MyPHPExt\\Test\\optionalNullableStream" = stream_tests.optionalNullableStream,
        .@"MyPHPExt\\Test\\closeStream" = stream_tests.closeStream,
        .@"MyPHPExt\\Test\\syncStream" = stream_tests.syncStream,
        .@"MyPHPExt\\Test\\checkStreamFailures" = stream_tests.checkStreamFailures,
        .@"MyPHPExt\\Test\\typedArgument" = typed_arguments.typedArgument,
        .@"MyPHPExt\\Test\\optionalTypedArgument" = typed_arguments.optionalTypedArgument,
        .@"MyPHPExt\\Test\\checkStringArguments" = typed_arguments.checkStringArguments,
        .@"MyPHPExt\\Test\\checkZvalStrings" = typed_arguments.checkZvalStrings,
        .@"MyPHPExt\\Test\\checkStringWriteFailure" = typed_arguments.checkStringWriteFailure,
        .hello = functions.hello,
        .greet = functions.greet,
        .@"MyPHPExt\\increment" = functions.increment,
        .@"MyPHPExt\\mapValues" = functions.mapValues,
        .@"MyPHPExt\\makeSumClosure" = closures.makeSumClosure,
        .@"MyPHPExt\\makeCounter" = closures.makeCounter,
        .@"MyPHPExt\\makeReference" = closures.makeReference,
        .@"MyPHPExt\\Test\\wrapClosure" = closure_tests.wrapClosure,
        .@"MyPHPExt\\Test\\makeHandlerClosure" = closure_tests.makeHandlerClosure,
        .@"MyPHPExt\\Test\\makeFnClosure" = closure_tests.makeFnClosure,
        .@"MyPHPExt\\Test\\allocatorBailout" = bailout.allocatorBailout,
        .@"MyPHPExt\\Test\\allocatorAlignment" = bailout.allocatorAlignment,
        .@"MyPHPExt\\Test\\nativeOutOfMemory" = bailout.nativeOutOfMemory,
        .@"MyPHPExt\\Test\\guardResources" = guard_tests.guardResources,
        .@"MyPHPExt\\Test\\superglobalsSnapshot" = superglobals.superglobalsSnapshot,
        .@"MyPHPExt\\Test\\mutateSuperglobals" = superglobals.mutateSuperglobals,
        .@"MyPHPExt\\Test\\referenceArgument" = reference_arguments.referenceArgument,
        .@"MyPHPExt\\Test\\createReference" = references.createReference,
        .@"MyPHPExt\\Test\\makeReference" = references.makeReference,
        .@"MyPHPExt\\Test\\setReference" = references.setReference,
        .@"MyPHPExt\\Test\\setReferenceSelf" = references.setReferenceSelf,
        .@"MyPHPExt\\Test\\createReferenceCopy" = references.createReferenceCopy,
        .@"MyPHPExt\\Test\\optionalReferenceArgument" = reference_arguments.optionalReferenceArgument,
        .@"MyPHPExt\\Test\\collectArguments" = named_arguments.collectArguments,
        .@"MyPHPExt\\Test\\checkedNamedArguments" = named_arguments.checkedNamedArguments,
        .@"MyPHPExt\\Test\\collectReferenceArguments" = named_arguments.collectAll,
        .@"MyPHPExt\\Test\\invokeArguments" = named_arguments.invokeArguments,
        .@"MyPHPExt\\Test\\newObject" = class_new.newObject,
        .@"MyPHPExt\\Test\\failNextFallible" = class_new.failNextFallible,
        .@"MyPHPExt\\Test\\cloneObject" = object_tests.cloneObject,
        .@"MyPHPExt\\Test\\objectProperties" = object_tests.objectProperties,
        .@"MyPHPExt\\Test\\hasObjectProperty" = object_tests.hasObjectProperty,
        .@"MyPHPExt\\Test\\initObject" = object_tests.initObject,
        .@"MyPHPExt\\Test\\constructObject" = object_tests.constructObject,
        .@"MyPHPExt\\Test\\objectView" = object_access.objectView,
        .@"MyPHPExt\\Test\\readObjectNative" = object_access.readObjectNative,
        .@"MyPHPExt\\Test\\writeObjectNative" = object_access.writeObjectNative,
        .@"MyPHPExt\\Test\\objectDimension" = object_access.objectDimension,
        .@"MyPHPExt\\Test\\checkObjectViews" = object_access.checkObjectViews,
        .@"MyPHPExt\\Test\\checkZendStrings" = string_tests.checkZendStrings,
        .@"MyPHPExt\\Test\\copyArray" = array_tests.copyArray,
        .@"MyPHPExt\\Test\\separateArray" = array_tests.separateArray,
        .@"MyPHPExt\\Test\\mergeArray" = array_tests.mergeArray,
        .@"MyPHPExt\\Test\\compareArrays" = array_tests.compareArrays,
        .@"MyPHPExt\\Test\\checkArrayHashTable" = array_tests.checkArrayHashTable,
        .@"MyPHPExt\\Test\\isArrayList" = array_tests.isArrayList,
        .@"MyPHPExt\\Test\\arrayToList" = array_tests.arrayToList,
        .@"MyPHPExt\\Test\\iterateArray" = iteration.iterateArray,
        .@"MyPHPExt\\Test\\lookupKey" = iteration.lookupKey,
        .@"MyPHPExt\\Test\\storeKey" = iteration.storeKey,
        .@"MyPHPExt\\Test\\deleteKey" = iteration.deleteKey,
        .@"MyPHPExt\\Test\\iterateWhileMutating" = iteration.iterateWhileMutating,
        .@"MyPHPExt\\Test\\buildList" = iteration.buildList,
        .@"MyPHPExt\\Test\\checkArrayCallbacks" = boundaries.checkArrayCallbacks,
        .@"MyPHPExt\\Test\\checkObjectPropertyHandlers" = boundaries.checkObjectPropertyHandlers,
        .@"MyPHPExt\\Test\\checkObjectCreation" = boundaries.checkObjectCreation,
        .@"MyPHPExt\\Test\\lookupClass" = class_entry.lookupClass,
        .@"MyPHPExt\\Test\\readStaticProperty" = class_entry.readStaticProperty,
        .@"MyPHPExt\\Test\\checkConstantMetadata" = class_entry.checkConstantMetadata,
        .@"MyPHPExt\\Test\\readConstant" = class_entry.readConstant,
        .@"MyPHPExt\\Test\\readClassConstant" = class_entry.readClassConstant,
        .@"MyPHPExt\\Test\\setMixedProperty" = property_tests.setMixedProperty,
        .@"MyPHPExt\\Test\\setMixedReferenceProperty" = property_tests.setMixedProperty,
        .@"MyPHPExt\\Test\\castValue" = zval_tests.castValue,
        .@"MyPHPExt\\Test\\castReferenceValue" = zval_tests.castValue,
    });

    phpz.module(.{
        .name = extension.name,
        .version = extension.version,
        .classes = &(api.classes.* ++ .{ gc.Class, serialization.Class } ++ closures.classes ++ class_new.classes),
        .ini = ini.definitions,
        .globals = metrics.Globals,
        .observer = metrics.observer,
        .request_startup_fn = metrics.requestStartup,
        .info_fn = info,
    });
}
