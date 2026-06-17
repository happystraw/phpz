#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
PHP_BIN="${PHP_BIN:-$(command -v php)}"
SKEL="$ROOT_DIR/tools/phpz_skel.php"
PHPZ_REF="${PHPZ_REF:-dev}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/phpz-skel.XXXXXX")"

cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
    echo "not ok - $*" >&2
    exit 1
}

note() {
    echo "==> $*"
}

assert_file() {
    [ -f "$1" ] || fail "expected file: $1"
}

assert_executable() {
    [ -x "$1" ] || fail "expected executable file: $1"
}

assert_dir() {
    [ -d "$1" ] || fail "expected directory: $1"
}

assert_no_path() {
    [ ! -e "$1" ] || fail "expected path to be absent: $1"
}

assert_contains() {
    local file="$1"
    local needle="$2"
    grep -F -- "$needle" "$file" >/dev/null || {
        echo "--- $file" >&2
        sed -n '1,160p' "$file" >&2 || true
        fail "expected '$needle' in $file"
    }
}

assert_not_contains() {
    local file="$1"
    local needle="$2"
    if grep -F -- "$needle" "$file" >/dev/null; then
        echo "--- $file" >&2
        sed -n '1,160p' "$file" >&2 || true
        fail "did not expect '$needle' in $file"
    fi
}

new_case() {
    CASE_DIR="$TMP_ROOT/$1"
    mkdir -p "$CASE_DIR/out"
}

target_dir() {
    printf '%s/demo_ext' "$CASE_DIR/out"
}

run_skel() {
    local stdout="$CASE_DIR/stdout"
    local stderr="$CASE_DIR/stderr"
    if ! env ZIG="$ZIG_BIN" "$PHP_BIN" "$SKEL" "$@" > >(tee "$stdout") 2> >(tee "$stderr" >&2); then
        fail "command failed unexpectedly: php tools/phpz_skel.php $*"
    fi
}

run_zig() {
    shift
    if ! (cd "$(target_dir)" && "$ZIG_BIN" "$@"); then
        fail "$ZIG_BIN $* failed"
    fi
}

run_php_ri() {
    local label="$1"
    local stdout="$CASE_DIR/$label.stdout"
    local stderr="$CASE_DIR/$label.stderr"
    if ! (cd "$(target_dir)" && "$PHP_BIN" -dextension=modules/demo_ext.so --ri demo_ext \
        > >(tee "$stdout") 2> >(tee "$stderr" >&2)); then
        fail "php --ri demo_ext failed"
    fi
    assert_contains "$stdout" "demo_ext"
    assert_contains "$stdout" "0.1.0"
}

ZIG_BIN="${ZIG:-zig}"
PHP_CONFIG_BIN="${PHP_CONFIG:-$(command -v php-config || true)}"
command -v "$ZIG_BIN" >/dev/null 2>&1 || fail "zig is required"
[ -n "$PHP_CONFIG_BIN" ] || fail "php-config is required"
PHP_INCLUDE_DIR="$("$PHP_CONFIG_BIN" --include-dir)"

note "lint and help"
"$PHP_BIN" -l "$SKEL" >/dev/null
"$PHP_BIN" "$SKEL" --help >"$TMP_ROOT/help"
assert_contains "$TMP_ROOT/help" "--with-php-config <path>"
assert_contains "$TMP_ROOT/help" "--without-run-tests"

note "default + zig build test"
new_case default_build
run_skel \
    --ext DemoExt \
    --dir "$CASE_DIR/out" \
    --phpz "$PHPZ_REF"
assert_file "$(target_dir)/build.zig"
assert_dir "$(target_dir)/tests"
assert_executable "$(target_dir)/run-tests.php"
assert_contains "$(target_dir)/build.zig" 'const ext_name = "demo_ext";'
assert_contains "$(target_dir)/src/root.zig" '.name = "demo_ext",'
assert_contains "$(target_dir)/demo_ext.h" "extern zend_module_entry demo_ext_module_entry;"
assert_contains "$CASE_DIR/stdout" "extension:    demo_ext"
run_zig default-build-test build test
run_php_ri default-ri

note "explicit php-config + zig build test"
new_case explicit_php_config
run_skel \
    --ext demo_ext \
    --dir "$CASE_DIR/out" \
    --phpz "$PHPZ_REF" \
    --with-php-config "$PHP_CONFIG_BIN"
assert_contains "$CASE_DIR/stderr" "checking php-config... $PHP_CONFIG_BIN"
assert_contains "$(target_dir)/build.zig" "orelse \"$PHP_INCLUDE_DIR\""
assert_not_contains "$(target_dir)/build.zig" "php-config"
run_zig explicit-php-config-build-test build test
run_php_ri explicit-php-config-ri

note "without run-tests"
new_case without_run_tests
run_skel \
    --ext demo_ext \
    --dir "$CASE_DIR/out" \
    --phpz "$PHPZ_REF" \
    --without-run-tests
assert_no_path "$(target_dir)/tests"
assert_no_path "$(target_dir)/run-tests.php"
assert_not_contains "$(target_dir)/build.zig" "Run PHPT tests"
assert_not_contains "$(target_dir)/build.zig" "run-tests.php"
assert_not_contains "$(target_dir)/README.md" "zig build test"
run_zig without-run-tests-build build
run_php_ri without-run-tests-ri

note "without gen-stub + zig build test"
new_case without_gen_stub
run_skel \
    --ext demo_ext \
    --dir "$CASE_DIR/out" \
    --phpz "$PHPZ_REF" \
    --without-gen-stub
assert_no_path "$(target_dir)/build/gen_stub.php"
assert_file "$(target_dir)/demo_ext_arginfo.h"
assert_dir "$(target_dir)/tests"
run_zig without-gen-stub-build-test build test
run_php_ri without-gen-stub-ri

note "ok"
