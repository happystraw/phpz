# PHP Extension Benchmarks

Three extensions implement the same functions and the same `Point` class:

- `c_ext` — a C extension using ZPP fast macros (`Z_PARAM_*`), `ZEND_HASH_FOREACH_*` and `ZEND_HASH_FILL_PACKED`.
- `cpp_ext` — the same work in idiomatic C++17 (`std::string_view`, `std::to_chars`, a `Point` type).
- `zig_ext` — the same work with phpz typed handlers, `phpz.Class`, `ModuleGlobals` and `zend.Array.ListBuilder`.

`tests.phpt.in` is one correctness test that every implementation must pass with identical output before
any benchmark runs.

## Running

```bash
./run.sh                        # build, test, then benchmark with the defaults
./run.sh --samples=21 --filter='array|method'
php -n -d extension=... bench.php --list
```

`build.sh` compiles C with `$CC $CFLAGS` (default `-O3`), C++ with `$CXX -std=c++17`, and the Zig extension with
`-Doptimize=$ZIG_OPTIMIZE` (default `ReleaseFast`), all against the PHP selected by `PHP` and `PHP_CONFIG`.
`run.sh` runs PHP with `-n`, so opcache and other INI-loaded extensions are off. Pin the process to one core for
quieter numbers, e.g. `taskset -c 3 php -n ... bench.php`.

## Methodology

- Every benchmark is an `eval`-generated loop with direct calls, so harness cost is a plain `for` loop. The
  `loop` row measures that overhead; it is included in every other row.
- Each round runs every implementation once, in an order shuffled per round with a fixed seed. Results are the
  median over rounds, with the interquartile range. A warmup of one fifth of the iterations precedes sampling.
- CPU time per operation comes from `getrusage`, and request memory is checked before and after each sample.
- A ratio is marked `~` when the medians differ by less than 3% or the interquartile ranges overlap.
  Do not add rows together; they measure unrelated work.
- `--json` stores every sample with machine, PHP and compiler metadata. The data behind the tables below is in
  [`reports/2026-10-18-linux-x86_64`](./reports/2026-10-18-linux-x86_64).

## Results

AMD Ryzen 5 5500 under WSL2 (Linux 6.6), PHP 8.4.26 release builds, gcc/g++ 13.3 `-O3`, Zig 0.17.0
`ReleaseFast`, 15 rounds of 200,000 iterations (divided for heavier rows), pinned to one core.
"Before" is phpz at `9c3798f`; "after" is this branch. Ratios are against C from the same run, lower is better.

| Benchmark | NTS C ns/op | NTS C++/C | NTS before/C | NTS after/C | ZTS C ns/op | ZTS C++/C | ZTS before/C | ZTS after/C |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Empty function call | 6.4 | 1.01 ~ | 1.03 ~ | 1.04 ~ | 7.7 | 0.99 ~ | 1.07 ~ | 1.07 ~ |
| `add(int, int)` | 10.6 | 0.97 ~ | 0.99 ~ | 0.95 | 11.2 | 1.06 ~ | 0.98 ~ | 0.97 ~ |
| `muladd(float ×3)` | 11.8 | 0.98 ~ | 1.03 ~ | 0.98 ~ | 12.8 | 1.00 ~ | 1.01 ~ | 0.98 ~ |
| 8 params, typed / fast ZPP | 20.5 | 0.98 ~ | 1.03 ~ | 0.98 ~ | 21.0 | 1.02 ~ | 1.04 ~ | 0.96 ~ |
| 8 params, `zend_parse_parameters` | 78.7 | 1.00 ~ | 1.01 ~ | 1.01 ~ | 81.4 | 0.99 ~ | 1.00 ~ | 1.02 ~ |
| `str_len(string)` | 8.9 | 0.99 ~ | 0.98 ~ | 1.02 ~ | 10.0 | 1.00 ~ | 0.98 ~ | 0.94 |
| `int_to_string(int)` | 23.5 | 1.00 ~ | 1.03 ~ | 0.98 ~ | 25.6 | 1.06 ~ | 1.04 ~ | 0.97 ~ |
| `str_upper`, 16 B | 15.2 | 1.01 ~ | 1.17 | 1.27 | 18.0 | 1.00 ~ | 1.03 ~ | 1.02 ~ |
| `str_upper`, 4 KiB | 223.9 | 0.77 | 0.73 | 0.71 | 173.5 | 1.31 | 0.94 | 0.92 |
| Packed array sum, 1k | 430.0 | 1.21 | 0.88 | 0.61 | 441.7 | 0.97 ~ | 1.00 ~ | 0.65 |
| Packed array sum, 1k, ZPP `"a"` | 439.9 | 1.00 ~ | 0.89 | 0.63 | 447.2 | 1.00 ~ | 0.89 | 0.67 |
| Assoc keys + values, 1k | 693.7 | 0.96 ~ | 1.11 | 1.06 ~ | 656.3 | 1.00 ~ | 1.10 | 1.19 |
| Build packed array, 1k | 553.2 | 0.99 ~ | 6.41 | 1.02 ~ | 569.8 | 1.54 | 6.18 | 0.99 ~ |
| Hash lookup, string key | 14.7 | 1.01 ~ | 1.02 ~ | 0.97 ~ | 15.2 | 1.00 ~ | 1.00 ~ | 1.00 ~ |
| Return argument array (refcount) | 8.8 | 0.97 ~ | 1.05 ~ | 1.02 ~ | 10.0 | 0.99 ~ | 1.10 | 1.04 ~ |
| Module globals read/write | 6.5 | 1.02 ~ | 1.03 ~ | 1.03 ~ | 11.7 | 1.01 ~ | 1.03 ~ | 0.91 |
| Call a PHP closure from native | 35.5 | 1.00 ~ | 1.02 ~ | 1.08 | 38.4 | 1.17 | 1.12 | 1.05 |
| `new Point` + destroy | 46.2 | 0.93 ~ | 0.98 ~ | 0.90 | 42.9 | 0.99 ~ | 1.07 | 1.04 ~ |
| Method call, native read | 10.6 | 1.01 ~ | 1.15 | 0.98 ~ | 11.0 | 1.00 ~ | 1.15 | 1.01 ~ |
| Method call, native write | 15.0 | 1.02 ~ | 1.14 | 0.98 ~ | 15.1 | 1.01 ~ | 1.07 | 0.99 ~ |
| Throw + catch exception | 286.4 | 0.99 ~ | 1.02 ~ | 0.99 ~ | 325.3 | 1.01 ~ | 1.01 ~ | 0.99 ~ |
| `split`, 64 fields (end to end) | 1088.6 | 1.06 ~ | 1.25 | 1.18 | 984.5 | 1.17 | 1.21 | 1.21 |
| split + upper + len per field | 3179.0 | 1.02 ~ | 1.13 | 1.08 | 3690.3 | 1.13 ~ | 1.11 | 1.18 ~ |
| Mixed calls, sustained | 34.2 | 1.13 | 1.01 ~ | 1.05 | 46.4 | 0.95 | 1.02 ~ | 0.95 ~ |

Absolute numbers move by several percent between runs on this machine; compare ratios within a run.

### Where the differences come from

- **Calls and argument parsing** — phpz handlers are a single type compare per argument, like `Z_PARAM_*`, with
  error and coercion paths out of line. Most rows are within noise of C.
- **Packed iteration** — `eachValue` uses a separate constant-stride loop for packed arrays, which the
  compiler unrolls further than `ZEND_HASH_FOREACH_VAL`'s runtime-stride loop.
- **Array construction** — `zend.Array.ListBuilder` matches `ZEND_HASH_FILL_PACKED`; before this branch phpz could only
  append through `zend_hash_next_index_insert`.
- **Methods** — receivers rely on Zend's guarantee that instance methods run with an object `$this`, so they no
  longer pay for `instanceof` and backing checks that cannot fail.
- **ZTS globals** — phpz reads PHP's own TLS cache through the offset PHP exports for its JIT, one load on Linux,
  where C extensions call `__tls_get_addr` for `ZEND_TSRMLS_CACHE`.
- **Closure calls** stay a few percent behind because `Callable.call` copies the call info and checks
  `EG(exception)` to return `error.PhpException`; the C version ignores the result.
- **`str_upper`** — gcc auto-vectorizes the C byte loop; Zig 0.17 does not vectorize the equivalent scalar loop,
  even with `noalias`, so the Zig version uses `@Vector(16, u8)`. The NTS 16-byte gap sits in that loop rather
  than in phpz: `int_to_string` allocates and returns a string through the same path at parity.
- **`split`** spends its time in `std.mem.splitSequence` against `zend_memnstr`; both append with
  `add_next_index_stringl`.
- **Assoc iteration** compiles to the same instructions as C, dominated by the dependent key length load; the
  remaining gap varies between runs.

Not measured here: peak memory under concurrent ZTS load, PHP 8.2/8.3/8.5 release builds (only debug builds
were available locally), macOS, aarch64 and Windows.

## Structure

```
benchmark/
├── run.sh          build, test and benchmark in one step
├── build.sh        build all three extensions and run tests.phpt.in against each
├── bench.php       benchmark runner
├── tests.phpt.in   shared correctness test
├── reports/        raw results behind published numbers
├── c_ext/          C extension
├── cpp_ext/        C++ extension
└── zig_ext/        phpz extension
```
