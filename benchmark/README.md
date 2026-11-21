# PHP extension benchmarks

Three native PHP extensions serve the same API. C uses Zend directly. PHPX
uses the public Swoole PHPX wrappers. PHPZ uses phpz bindings, typed handlers,
and the public array and object helpers.

The primary goal is to detect performance regressions in PHPZ relative to the
Zend C baseline. Track the PHPZ/C time ratio for each workload across revisions
on the same machine and PHP build. A ratio above 1 means PHPZ took longer than C
in that run. An increase from the recorded baseline ratio is the signal to
investigate for a regression. PHPX provides a second extension API comparison.

## Run

Use Linux x86_64 with a 64-bit release build of PHP 8.4 or 8.5. Install the
matching development headers and `php-config`, plus Zig, C and C++17 compilers,
CMake, GMP and MPFR development packages, curl, and util-linux.

```sh
benchmark/run.sh --check
benchmark/run.sh
benchmark/run.sh --filter=sum/ --json=/tmp/array-bench.json
```

The first run downloads and verifies the pinned Swoole PHPX v2.9.8 source.
The build stays under `benchmark/.build/`. Set `PHP` and `PHP_CONFIG` together to select
another installation. Set `BENCH_CPU` to select a CPU from the current
affinity mask. The default is the first allowed CPU.

Use `--rounds=6 --target-ms=2` for a quick smoke run. The default is
36 rounds with a calibration target of 50 ms for the fastest implementation.
Workloads run in natural name order. Use `--seed` to reproduce the order of implementations within rounds.

## Compiler optimizations

The default suite compares release builds targeting the host x86-64 CPU.

| Implementation | Build settings |
|---|---|
| C | `-O3 -DNDEBUG -march=native` |
| PHPX | CMake `Release` for `libphpx.so`. The library and the benchmark extension both use `-O3 -DNDEBUG -march=native` |
| PHPZ | Zig `-Doptimize=ReleaseFast -Dcpu=native` |

LTO is off for the default comparison. The JSON report includes the compiler
versions and optimization flags.

## Workloads

| Case | Operation |
|---|---|
| `args` | Decode an integer, string, float, bool and optional nullable integer and return a checksum |
| `array/cow` | Change the first element of a shared 1,024-element list and return the separated array |
| `build` | Construct and release a packed array of 16 or 1,024 integers |
| `call` | Call an empty internal function |
| `callback` | Resolve a pre-created PHP closure, invoke it once, and return its result. PHPZ uses `Callable.callAssumeExclusive()` on the callable from typed argument parsing. |
| `lookup/hit`, `lookup/miss` | Look up an existing or missing string key in a 1,024-entry map |
| `method` | Read a typed property through an internal method on a pre-created object |
| `pipeline` | Split a 64-field record, uppercase each field and sum their byte lengths |
| `sum` | Sum integers in packed and string-key arrays of 16 or 1,024 values |
| `sum/holes/1024` | Sum a packed array with every fourth slot removed |
| `sum/mixed/1024` | Sum integers and integer references while skipping strings and floats |

C and PHPZ use their packed-array builders. PHPX uses its public pre-sized
array and append API. All three string pipelines use the same Zend split
and uppercase primitives.

## Measurement

The three extensions share one PHP stub, one suite of correctness checks,
and one direct-call driver. Every sample starts a new PHP CLI process with
one extension and OPcache and JIT disabled. Fixture setup and warmup run
before the monotonic timer starts. Reported time includes the PHP loop and
all calls and return-value handling inside it.

Each round runs all three implementations at the same calibrated iteration
count. The six execution orders occur equally often and are shuffled using
the recorded seed. The console shows median nanoseconds per operation and the
median of the within-round time ratios. A ratio below 1 means lower time for
its numerator. The 95% intervals use 5,000 bootstrap resamples of whole
rounds. They describe variation across repeats of the measured build on
the recorded machine. Run from a quiet machine and repeat sessions before
interpreting small differences.

`benchmark/results/latest.json` stores the order, timings, iteration counts,
ratios, confidence intervals, module hashes, and build metadata. The shared
GitHub Actions runner runs the build and correctness checks.

To regenerate the shared PHP arginfo after changing `zig/bench_zig.stub.php`, run
`php tools/php/gen_stub.php benchmark/zig/bench_zig.stub.php` from the repository root.

## Benchmark results

Intel Core i5-10600 (logical CPU 4), Linux x86-64, PHP 8.5.13 NTS,
GCC 16.2.1, Zig 0.17.0 and PHPX v2.9.8. Each workload ran for 36 rounds
with a 50 ms calibration target. ⚡ marks the lowest median time (ns/op) in each row.

| Workload | C | PHPZ(ZIG) | PHPX(C++) | PHPZ / C (95% CI) |
|---|---:|---:|---:|---:|
| `args/int` | 16.26 | 15.08 ⚡ | 91.38 | 0.935 [0.917, 0.947] |
| `args/null` | 14.36 | 13.99 ⚡ | 92.34 | 0.970 [0.956, 0.991] |
| `args/omitted` | 14.78 | 13.18 ⚡ | 82.30 | 0.889 [0.874, 0.901] |
| `array/cow` | 972.98 | 970.84 ⚡ | 1,064.12 | 0.996 [0.984, 1.007] |
| `build/16` | 35.48 | 34.63 ⚡ | 214.89 | 0.984 [0.970, 0.997] |
| `build/1024` | 814.24 | 806.39 ⚡ | 10,799.14 | 1.003 [0.984, 1.011] |
| `call` | 5.26 ⚡ | 5.90 | 10.62 | 1.123 [1.112, 1.132] |
| `callback` | 43.12 ⚡ | 45.71 | 106.88 | 1.061 [1.054, 1.074] |
| `lookup/hit` | 19.15 ⚡ | 20.02 | 69.61 | 1.038 [1.018, 1.059] |
| `lookup/miss` | 16.38 ⚡ | 18.08 | 67.96 | 1.108 [1.093, 1.122] |
| `method` | 30.92 ⚡ | 31.19 | 48.38 | 1.010 [0.998, 1.019] |
| `pipeline` | 2,959.12 | 2,911.12 ⚡ | 6,687.20 | 0.995 [0.978, 1.010] |
| `sum/holes/1024` | 597.92 | 313.03 ⚡ | 2,184.72 | 0.521 [0.516, 0.529] |
| `sum/map/16` | 14.56 | 13.87 ⚡ | 74.08 | 0.951 [0.946, 0.957] |
| `sum/map/1024` | 458.81 | 349.35 ⚡ | 2,554.79 | 0.765 [0.758, 0.771] |
| `sum/mixed/1024` | 836.58 | 358.95 ⚡ | 2,574.77 | 0.430 [0.423, 0.432] |
| `sum/packed/16` | 16.44 | 13.70 ⚡ | 73.54 | 0.835 [0.828, 0.843] |
| `sum/packed/1024` | 454.94 | 287.57 ⚡ | 2,534.34 | 0.633 [0.627, 0.637] |
