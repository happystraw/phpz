const phpz = @import("phpz");

const api = @import("api.zig");
const functions = @import("functions.zig");
const ini = @import("ini.zig");
const metrics = @import("metrics.zig");
const bailout = @import("testing/bailout.zig");
const superglobals = @import("testing/superglobals.zig");
const reference_arguments = @import("testing/reference_arguments.zig");
const named_arguments = @import("testing/named_arguments.zig");
const closure_tests = @import("testing/closures.zig");
const gc = @import("testing/gc.zig");
const serialization = @import("testing/serialization.zig");
const closures = @import("closures.zig");

fn info(m: *phpz.ModuleEntry) void {
    phpz.info.table.start();
    phpz.info.table.header(.{ "my_php_extension support", "enabled" });
    phpz.info.table.row(.{ "version", m.version });
    phpz.info.table.end();
}

comptime {
    @setEvalBranchQuota(10_000);
    const extension = @import("extension_info");

    phpz.namedFunctions(.{
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
        .@"MyPHPExt\\Test\\superglobalsSnapshot" = superglobals.superglobalsSnapshot,
        .@"MyPHPExt\\Test\\mutateSuperglobals" = superglobals.mutateSuperglobals,
        .@"MyPHPExt\\Test\\referenceArgument" = reference_arguments.referenceArgument,
        .@"MyPHPExt\\Test\\collectArguments" = named_arguments.collectArguments,
        .@"MyPHPExt\\Test\\checkedNamedArguments" = named_arguments.checkedNamedArguments,
        .@"MyPHPExt\\Test\\collectReferenceArguments" = named_arguments.collectAll,
        .@"MyPHPExt\\Test\\invokeArguments" = named_arguments.invokeArguments,
    });

    phpz.module(.{
        .name = extension.name,
        .version = extension.version,
        .classes = &(api.classes.* ++ .{ gc.Class, serialization.Class } ++ closures.classes),
        .ini = ini.definitions,
        .globals = metrics.Globals,
        .observer = metrics.observer,
        .request_startup_fn = metrics.requestStartup,
        .info_fn = info,
    });
}
