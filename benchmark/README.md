# PHP Extension Performance Benchmarks

C vs Zig (phpz) — identical PHP extension implementations benchmarked head-to-head.

## Quick Start

```bash
./run.sh [--iterations=N]
```

Runs: C build + test, Zig build + test, then benchmarks. Default 1,000,000 iterations.

## Results

Linux, PHP 8.5.8, Zig 0.17.0-dev.1282, 1M iterations × 10 runs averaged. C uses `-O3`; Zig uses `ReleaseFast`. Lower is better.

| Benchmark | C ns/call | Zig ns/call | Winner |
|---|---|---|---|
| Empty function call | 28.2 | 29.3 | — (tie) |
| Parse 8 params (macro/fast) | 60.6 | 61.7 | — (tie) |
| Parse 8 params (parse/zpp) | **139.1** | 141.1 | C 1.4% |
| Array sum 1k (macro/fast) | 448.3 | **316.5** | Zig 29.4% |
| Array sum 1k (parse/zpp) | 463.9 | **339.8** | Zig 26.8% |
| **TOTAL** | 1140.1 | **888.3** | **Zig 22.1%** |

### Takeaways

- **Function call overhead**: no meaningful difference (~1.1ns per call).
- **Parameter parsing**: the fast paths are effectively tied (~1.1ns); C's traditional path is ~2ns faster.
- **Array iteration**: Zig's inline `eachValue` beats C's `ZEND_HASH_FOREACH_VAL` by 27–29%.
  The IS_UNDEF check and user type check are in the same compiler scope, eliminating
  redundant branch evaluation.

## Benchmarks

| Function | Parsing | Description |
|---|---|---|
| `bench_{c,zig}_empty()` | — | Empty function call overhead |
| `bench_{c,zig}_parse_multi(...)` | macro / expect | Parse 8 params: long, string, double, bool, array, object, mixed, optional long |
| `bench_{c,zig}_parse_multi_pp(...)` | zpp / parse | Same, using traditional parameter parsing |
| `bench_{c,zig}_array_sum_fast(...)` | macro / expect | Sum 1k integers, modern parsing |
| `bench_{c,zig}_array_sum_parse(...)` | zpp / parse | Sum 1k integers, traditional parsing |

## Manual Build

### C Extension

```bash
cd c_ext
phpize
CFLAGS="-O3" ./configure
make
make test
```

### Zig Extension

```bash
cd zig_ext
zig build -Doptimize=ReleaseFast -Dphp-include-dir=$(php-config --include-dir)
zig build run-tests -Doptimize=ReleaseFast -Dphp-include-dir=$(php-config --include-dir)
```

### Run

```bash
php -d "extension=c_ext/modules/bench_c.so" \
    -d "extension=zig_ext/modules/bench_zig.so" \
    run.php [--iterations=N]
```

## Structure

```
bench/
├── run.sh                      # one-shot: build + test + benchmark
├── run.php                     # PHP benchmark runner
├── c_ext/                      # Traditional C PHP extension
│   ├── bench_c.c               #   benchmark implementations
│   ├── bench_c.stub.php        #   PHP stub for arginfo generation
│   ├── bench_c_arginfo.h       #   generated arginfo
│   └── tests/                  #   PHPT tests
└── zig_ext/                    # Zig PHP extension (phpz)
    ├── src/root.zig            #   benchmark implementations
    ├── bench_zig.stub.php      #   PHP stub for arginfo generation
    ├── bench_zig_arginfo.h     #   generated arginfo
    ├── build.zig               #   Zig build + test step
    └── tests/                  #   PHPT tests
```
