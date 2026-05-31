# PHP Extension Performance Benchmarks

C vs Zig (phpz) — identical PHP extension implementations benchmarked head-to-head.

## Quick Start

```bash
./run.sh [--iterations=N]
```

Runs: C build + test, Zig build + test, then benchmarks. Default 1,000,000 iterations.

## Results

macOS 14, PHP 8.2.31, Zig 0.16.0, 1M iterations, ReleaseFast. Lower is better.

| Benchmark | C ns/call | Zig ns/call | Winner |
|---|---|---|---|
| Empty function call | 61.6 | 65.7 | — (tie) |
| Parse 8 params (macro/fast) | 128.4 | 128.6 | — (tie) |
| Parse 8 params (parse/zpp) | 228.0 | **222.1** | Zig 2.6% |
| Array sum 1k (macro/fast) | 651.9 | **467.2** | Zig 28.3% |
| Array sum 1k (parse/zpp) | 677.8 | **484.3** | Zig 28.6% |
| **TOTAL** | 1747.8 | **1367.8** | **Zig 21.7%** |

### Takeaways

- **Function call overhead**: identical (~4ns diff, within noise).
- **Parameter parsing**: Zig's `expectArgs` matches C's fast `Z_PARAM` macro. The traditional
  `zend_parse_parameters` path is comparable between languages.
- **Array iteration**: Zig's inline `eachValue` beats C's `ZEND_HASH_FOREACH_VAL` by ~28%.
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
phpize && ./configure && make
make test
```

### Zig Extension

```bash
cd zig_ext
zig build -Doptimize=ReleaseFast -Dphp-include-dir=$(php-config --include-dir)
zig build test -Doptimize=ReleaseFast -Dphp-include-dir=$(php-config --include-dir)
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
