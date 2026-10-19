#!/usr/bin/env bash
# Build all benchmark extensions, then run bench.php with them loaded.
# Extra arguments go to bench.php, e.g. ./run.sh --samples=21 --filter=array
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PHP="${PHP:-php}"
CC="${CC:-cc}"
CXX="${CXX:-c++}"
ZIG="${ZIG:-zig}"

"$DIR/build.sh"

mkdir -p "$DIR/results"
stamp="$(date +%Y%m%d-%H%M%S)"
export BENCH_CC_VERSION="$("$CC" --version | head -1)"
export BENCH_CXX_VERSION="$("$CXX" --version | head -1)"
export BENCH_ZIG_VERSION="$("$ZIG" version)"
export BENCH_CFLAGS="${CFLAGS:--O3}"
export BENCH_ZIG_OPTIMIZE="${ZIG_OPTIMIZE:-ReleaseFast}"

exec "$PHP" -n \
    -d "extension=$DIR/c_ext/modules/bench_c.so" \
    -d "extension=$DIR/cpp_ext/modules/bench_cpp.so" \
    -d "extension=$DIR/zig_ext/modules/bench_zig.so" \
    "$DIR/bench.php" --json="$DIR/results/$stamp.json" "$@"
