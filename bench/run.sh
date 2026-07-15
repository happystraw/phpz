#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PHP_INCLUDE_DIR="$(php-config --include-dir)"

echo "=== Building C extension ==="
(
    cd "$SCRIPT_DIR/c_ext"
    git clean -fdX
    phpize
    CFLAGS="-O3" ./configure --with-php-config="$(which php-config)"
    make
    echo "  C extension built"
    php run-tests.php -d "extension=$SCRIPT_DIR/c_ext/modules/bench_c.so" --show-diff -q
)

echo ""
echo "=== Building Zig extension ==="
(
    cd "$SCRIPT_DIR/zig_ext"
    git clean -fdX
    cp "$SCRIPT_DIR/c_ext/run-tests.php" .
    zig build -Doptimize=ReleaseFast -Dphp-include-dir="$PHP_INCLUDE_DIR"
    echo "  Zig extension built"
    zig build run-tests -Doptimize=ReleaseFast -Dphp-include-dir="$PHP_INCLUDE_DIR"
)

echo ""
echo "=== Running benchmarks ==="
exec php \
    -d "extension=$SCRIPT_DIR/c_ext/modules/bench_c.so" \
    -d "extension=$SCRIPT_DIR/zig_ext/modules/bench_zig.so" \
    "$SCRIPT_DIR/run.php" \
    "$@"
