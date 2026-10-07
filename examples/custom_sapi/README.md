# Custom SAPI

A standalone PHP host that runs a script file or `-r` code and registers
`custom_sapi_greeting(): string` as a built-in function. The implementation is in
[src/main.zig](src/main.zig).

## Build and run

Provide a PHP embed library and matching headers. Architecture, libc, thread
safety (NTS/ZTS) and debug mode must match the PHP build.

PHP is linked **statically by default**: `libphp.a` on Linux/macOS or
`php8embed.lib` on Windows. To build one with SPC v3, run from its checkout:

```sh
php bin/spc build:php bcmath --build-embed
php bin/spc spc-config bcmath --with-packages=php --libs-only-deps
```

Add `--enable-zts` for ZTS. Use an MSVC developer shell on Windows. For Linux
Docker builds, use SPC's `bin/spc-alpine-docker` wrapper and export `buildroot`.

From this example directory, build against that library. Add the dependencies
reported by `spc-config` using `-Dlink-lib=NAME` for each library and
`-Dlink-framework=NAME` for each macOS framework:

```sh
zig build install run-tests \
  -Dphp-include-dir=/path/to/php/include/php \
  -Dphp-lib-dir=/path/to/php/lib
./zig-out/bin/custom-sapi hello.php
./zig-out/bin/custom-sapi -r 'echo custom_sapi_greeting(), PHP_EOL;'
```

Additional options:

- `-Dshared=true`: link a shared PHP library. On Unix, build PHP with
  `--enable-embed=shared`; on Windows, use matching runtime and development
  packages and place their DLLs beside `custom-sapi.exe`.
- `-Dtarget=x86_64-linux-musl`: match an x86_64 musl PHP build.
- `-Dtarget=x86_64-windows-msvc`: target Windows. Set `-Dwindows-zts=true`,
  `-Dwindows-debug=true` and `-Dlibc-file=...` as needed for the PHP/toolchain build.
  The pinned SPC Windows build uses the PHP source directory as `php-include-dir`.
- `-Dforce-undefined-symbol=NAME`: retain a symbol from a static library.
  This option, `link-lib` and `link-framework` can be repeated.

PHP linking does not fall back between static and dynamic modes. Static PHP does
not imply a fully static executable. See the [CI script](../../.github/scripts/test-sapi.sh)
for complete platform-specific arguments.

## Lifecycle and ownership

[src/main.zig](src/main.zig) shows the startup order and matching cleanup:

1. Start TSRM with `phpz.tsrm.startup()` and initialize Zend signals with
   `phpz.zend.signal.startup()`.
2. Call `Sapi.init(config)`, then `sapi.startup(&addon_module)` to start PHP.
   Pass `null` if no additional module is needed.
3. Bind the backend with `Sapi.setContext(&backend)`, prepare request metadata,
   and call `phpz.sapi.request.startup()`. Execute PHP, shut down the request on
   the same thread, then clear the context with `Sapi.setContext(null)`.
4. After all requests and worker threads finish, call `sapi.shutdown()`,
   `sapi.deinit()` and `phpz.tsrm.shutdown()`.

Only one SAPI may be active per process. Keep the SAPI instance alive until
`deinit()`, and the INI text and `initModuleEntry()` storage alive through module
shutdown. The additional module is selected at startup. `initModuleEntry()`
does not export a dynamic-extension loader entry point.

The backend and borrowed request strings must outlive request shutdown, which
can still run PHP callbacks and produce output. Mandatory host cleanup belongs
outside bailout boundaries; `deactivate` is not a guaranteed destructor.

Install module/request shutdown defers only after their corresponding startup
succeeds. A failed request startup can leave partial PHP state: tear down the
host, preserving borrowed resources through cleanup, rather than retrying.

## Execution and errors

Use these APIs inside an active request:

| Input | API | Behavior |
| --- | --- | --- |
| Code without `<?php` | `phpz.tryEval(code, null, name)` | Leaves exceptions pending as `error.PhpException`; `name` identifies diagnostics. |
| Script file | `phpz.tryExecuteScript(file)` | Uses PHP's script runner, which reports exceptions and returns `error.ScriptExecutionFailed` for internally caught failures. |

For a file, initialize `zend.FileHandle` inside `zend.bailout.run`, set
`setPrimaryScript(true)`, and call `deinit()` before request shutdown. The handle
copies the filename and opens the file lazily; initialization can itself bail out.

`phpz.errors.takeUnwindExit()` consumes a pending `exit`/`die` signal and returns
`?phpz.errors.ExitStatus` (`.ok = 0`, with unnamed exit codes preserved). It leaves
ordinary exceptions untouched. PHP's file runner can return failure even for
`exit(0)`; follow the status and fatal-error checks in the example. Check the
final exit status after request shutdown, which can also fail.

Both `try` APIs catch escaping bailouts as `error.ZendBailout`; after one, finish
request shutdown instead of continuing PHP execution. The lower-level `eval`
and `executeScript` do not add this outer boundary. Exception reporting needs
its own boundary because it can execute PHP code. A bailout skips Zig defers
inside the boundary.

To evaluate an expression, pass a pointer to a `Zval` initialized to PHP undef
instead of `null` to `tryEval`. PHP wraps the code as `return <code>;`; release
the result before request shutdown.

## Callbacks

This example implements `ub_write` and buffers output until request shutdown.
It must write all bytes or return an error. `ub_write` and `flush` errors mark
the connection aborted; `ignore_user_abort` controls PHP termination.

For HTTP backends, prepare body and cookie state before request startup: PHP may
read them before `activate`. `read_post` must fill the buffer unless the request
body ends; a short read means EOF. Handle transport short reads internally and
respect the request-body boundary. See [sapi.Options](../../src/sapi.zig) for
callback ownership and error contracts.

## Tests and API changes

`zig build run-tests` uses a PHP CLI available as `php` to launch the host and
check output, errors and exit status. Reuse the PHP paths and link options from
your build. The suite covers file/`-r` execution, shutdown, fatal errors and exits;
it does not exercise an HTTP backend.

After editing [custom_sapi.stub.php](custom_sapi.stub.php), regenerate arginfo:

```sh
zig build gen-stub
```

Update the Zig bindings in `src/main.zig` and rebuild against the same PHP
configuration.
