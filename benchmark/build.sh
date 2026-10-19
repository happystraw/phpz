#!/usr/bin/env bash
# Build the C, C++ and phpz benchmark extensions against one PHP and check
# that all three produce the reference results.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PHP="${PHP:-php}"
PHP_CONFIG="${PHP_CONFIG:-php-config}"
CC="${CC:-cc}"
CXX="${CXX:-c++}"
CFLAGS="${CFLAGS:--O3}"
ZIG="${ZIG:-zig}"
ZIG_OPTIMIZE="${ZIG_OPTIMIZE:-ReleaseFast}"

INCLUDE_DIR="$("$PHP_CONFIG" --include-dir)"
read -r -a INCLUDES <<< "$("$PHP_CONFIG" --includes)"
case "$(uname -s)" in
    Darwin) SHARED=(-bundle -undefined dynamic_lookup) ;;
    *) SHARED=(-shared) ;;
esac
COMMON=(-fPIC -D_GNU_SOURCE -DZEND_COMPILE_DL_EXT=1 -DZEND_ENABLE_STATIC_TSRMLS_CACHE=1)

mkdir -p "$DIR/c_ext/modules" "$DIR/cpp_ext/modules"

echo "=== C extension ($CC $CFLAGS)"
# shellcheck disable=SC2086
"$CC" $CFLAGS "${COMMON[@]}" -DCOMPILE_DL_BENCH_C=1 "${INCLUDES[@]}" -I"$DIR/c_ext" \
    "$DIR/c_ext/bench_c.c" "${SHARED[@]}" -o "$DIR/c_ext/modules/bench_c.so"

echo "=== C++ extension ($CXX $CFLAGS -std=c++17)"
# shellcheck disable=SC2086
"$CXX" $CFLAGS -std=c++17 "${COMMON[@]}" -DCOMPILE_DL_BENCH_CPP=1 "${INCLUDES[@]}" -I"$DIR/cpp_ext" \
    "$DIR/cpp_ext/bench_cpp.cpp" "${SHARED[@]}" -o "$DIR/cpp_ext/modules/bench_cpp.so"

echo "=== Zig extension (phpz, $ZIG_OPTIMIZE)"
(cd "$DIR/zig_ext" && "$ZIG" build -Doptimize="$ZIG_OPTIMIZE" -Dphp-include-dir="$INCLUDE_DIR")

cp "$DIR/../tools/php/run-tests.php" "$DIR/run-tests.php"
for impl in c:bench_c:BenchCPoint cpp:bench_cpp:BenchCppPoint zig:bench_zig:BenchZigPoint; do
    IFS=: read -r name ext class <<< "$impl"
    mkdir -p "$DIR/${name}_ext/tests"
    sed -e "s/@PREFIX@/$ext/g" -e "s/@EXT@/$ext/g" -e "s/@CLASS@/$class/g" \
        "$DIR/tests.phpt.in" > "$DIR/${name}_ext/tests/bench.phpt"
    "$PHP" "$DIR/run-tests.php" -q --show-diff -d "extension=$DIR/${name}_ext/modules/$ext.so" "$DIR/${name}_ext/tests"
done
