# PHP Extension Performance Benchmarks

C vs Zig (phpz) — identical PHP extension implementations benchmarked head-to-head.

## Quick Start

```bash
./run.sh [--iterations=N]
```

Runs: C build + test, Zig build + test, then benchmarks. Default 1,000,000 iterations.

## Results

Linux, PHP 8.5.7, Zig 0.16.0, 1M iterations × 5 runs averaged, ReleaseFast. Lower is better.

| Benchmark | C ns/call | Zig ns/call | Winner |
|---|---|---|---|
| Empty function call | 29.7 | 30.4 | — (tie) |
| Parse 8 params (macro/fast) | 62.9 | 63.1 | — (tie) |
| Parse 8 params (parse/zpp) | 134.3 | **125.7** | Zig 6.4% |
| Array sum 1k (macro/fast) | 449.7 | **336.2** | Zig 25.2% |
| Array sum 1k (parse/zpp) | 462.6 | **338.9** | Zig 26.7% |
| **TOTAL** | 1139.2 | **894.3** | **Zig 21.5%** |

### Takeaways

- **Function call overhead**: identical (~1ns diff, within noise).
- **Parameter parsing**: Zig's `expectArgs` matches C's fast `Z_PARAM` macros (tie).
  The traditional `zend_parse_parameters` path is ~6% faster in Zig.
- **Array iteration**: Zig's inline `eachValue` beats C's `ZEND_HASH_FOREACH_VAL` by ~26%.
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
