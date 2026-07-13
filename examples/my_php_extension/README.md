# my_php_extension

This extension is the end-to-end feature example for phpz. Its public PHP API is
defined by `my_php_extension.stub.php`; Zig files implement that contract without
duplicating PHP type metadata.

## API groups

- Global functions: `hello()` and `greet()`.
- Namespace functions: `MyPHPExt\increment()` and `MyPHPExt\mapValues()`.
- Object model: `Identifiable`, `Entity`, `User`, `Status`, `Role`, and `Tag`.
- General-purpose classes: `Counter`, `Dumper`, and `Collection`.
- Runtime configuration: static `Config` accessors backed by typed INI entries.
- Request telemetry: static `Metrics::snapshot()` and `Metrics::reset()`.
- Regression-only API: `MyPHPExt\Test\allocatorBailout()`.

Every exported Zig handler carries a `/// PHP: ...` line matching its stub
signature. Internal helpers and observer callbacks intentionally do not.

## Metrics

`Metrics::snapshot()` returns request-local data grouped under `request`, `calls`,
`returns`, `errors`, and `exceptions`. Exception records contain copied class,
message, code, file, and line values; the observer keeps only the 16 most recent
records and reports overwritten records through `discarded`.

The fcall observer uses a fixed-depth timing stack and does not allocate. Calls to
the metrics and test APIs are excluded so observing a snapshot does not alter it.
