#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
PHP_BIN="${PHP_BIN:-$(command -v php)}"
SKEL="$ROOT_DIR/tools/phpz_skel.php"
PHPZ_REF="${PHPZ_REF:-dev}"
EXPECTED_VERSION="0.0.1"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/phpz-skel.XXXXXX")"

fail() {
    echo "not ok - $*" >&2
    exit 1
}

ZIG_BIN="${ZIG:-zig}"
PHP_CONFIG_BIN="${PHP_CONFIG:-$(command -v php-config || true)}"
command -v "$ZIG_BIN" >/dev/null 2>&1 || fail "zig is required"
PHP_INCLUDE_DIR="${PHP_INCLUDE_DIR:-}"
if [ -z "$PHP_INCLUDE_DIR" ]; then
    [ -n "$PHP_CONFIG_BIN" ] || fail "php-config or PHP_INCLUDE_DIR is required"
    PHP_INCLUDE_DIR="$("$PHP_CONFIG_BIN" --include-dir)"
fi

ZIG_BUILD_ARGS=()
[ -n "${ZIG_TARGET:-}" ] && ZIG_BUILD_ARGS+=("-Dtarget=$ZIG_TARGET")
[ -n "${LIBC_FILE:-}" ] && ZIG_BUILD_ARGS+=("-Dlibc-file=$LIBC_FILE")
[ -n "${PHP_INCLUDE_DIR:-}" ] && ZIG_BUILD_ARGS+=("-Dphp-include-dir=$PHP_INCLUDE_DIR")
[ -n "${PHP_LIB_DIR:-}" ] && ZIG_BUILD_ARGS+=("-Dphp-lib-dir=$PHP_LIB_DIR")
[ -n "${WINDOWS_ZTS:-}" ] && ZIG_BUILD_ARGS+=("-Dwindows-zts=$WINDOWS_ZTS")

case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*)
    IS_WINDOWS=1
    DEFAULT_EXTENSION_FILENAME="php_demo_ext.dll"
    ;;
*)
    IS_WINDOWS=0
    DEFAULT_EXTENSION_FILENAME="demo_ext.so"
    ;;
esac
EXTENSION_FILENAME="${PHPZ_EXTENSION_FILENAME:-$DEFAULT_EXTENSION_FILENAME}"

php_path() {
    if [ "$IS_WINDOWS" -eq 1 ] && command -v cygpath >/dev/null 2>&1; then
        cygpath -m "$1"
    else
        printf '%s' "$1"
    fi
}

SKEL_ARGS=()
while [ "$#" -gt 0 ]; do
    case "$1" in
    --)
        shift
        SKEL_ARGS=("$@")
        break
        ;;
    *)
        echo "unsupported test script argument: $1"
        exit 1
        ;;
    esac
done

cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

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
    if ! env ZIG="$ZIG_BIN" "$PHP_BIN" "$SKEL" "${SKEL_ARGS[@]}" "$@" > >(tee "$stdout") 2> >(tee "$stderr" >&2); then
        fail "command failed unexpectedly: php tools/phpz_skel.php ${SKEL_ARGS[*]} $*"
    fi
}

run_zig() {
    local label="$1"
    shift
    if ! (cd "$(target_dir)" && "$ZIG_BIN" "$@" "${ZIG_BUILD_ARGS[@]}"); then
        fail "$ZIG_BIN $* ${ZIG_BUILD_ARGS[*]} failed for $label"
    fi
}

run_php_ri() {
    local label="$1"
    local stdout="$CASE_DIR/$label.stdout"
    local stderr="$CASE_DIR/$label.stderr"
    if ! (cd "$(target_dir)" && "$PHP_BIN" "-dextension=modules/$EXTENSION_FILENAME" --ri demo_ext \
        > >(tee "$stdout") 2> >(tee "$stderr" >&2)); then
        fail "php --ri demo_ext failed"
    fi
    assert_contains "$stdout" "demo_ext"
    assert_contains "$stdout" "$EXPECTED_VERSION"
}

has_skel_arg() {
    local expected="$1"
    local arg
    for arg in "${SKEL_ARGS[@]}"; do
        [ "$arg" = "$expected" ] && return 0
    done
    return 1
}

assert_platform_template() {
    local build_file
    build_file="$(target_dir)/build.zig"
    if has_skel_arg "--onlyunix"; then
        assert_contains "$build_file" "This extension only supports Unix targets"
        assert_not_contains "$build_file" "php-lib-dir"
    elif has_skel_arg "--onlywindows"; then
        assert_contains "$build_file" "This extension only supports Windows targets"
        assert_contains "$build_file" "php-lib-dir"
    fi
}

note "lint and help"
"$PHP_BIN" -l "$SKEL" >/dev/null
"$PHP_BIN" "$SKEL" --help >"$TMP_ROOT/help"
assert_contains "$TMP_ROOT/help" "--with-php-config <path>"
assert_contains "$TMP_ROOT/help" "--without-run-tests"

note "default + zig build test"
new_case default_build
run_skel \
    --ext DemoExt \
    --dir "$(php_path "$CASE_DIR/out")" \
    --phpz "$PHPZ_REF"
assert_file "$(target_dir)/build.zig"
assert_dir "$(target_dir)/tests"
if [ "$IS_WINDOWS" -eq 1 ]; then
    assert_file "$(target_dir)/run-tests.php"
else
    assert_executable "$(target_dir)/run-tests.php"
fi
assert_platform_template
assert_contains "$(target_dir)/build.zig" "const extension_name = @tagName(package.name);"
assert_contains "$(target_dir)/build.zig" 'extension_info.addOption([:0]const u8, "version", extension_version);'
assert_contains "$(target_dir)/src/root.zig" ".name = extension.name,"
assert_contains "$(target_dir)/demo_ext.h" "extern zend_module_entry demo_ext_module_entry;"
assert_contains "$CASE_DIR/stdout" "extension:    demo_ext"
run_zig default-build-test build test
run_php_ri default-ri

if [ -n "$PHP_CONFIG_BIN" ]; then
    note "explicit php-config + zig build test"
    new_case explicit_php_config
    run_skel \
        --ext demo_ext \
        --dir "$(php_path "$CASE_DIR/out")" \
        --phpz "$PHPZ_REF" \
        --with-php-config "$PHP_CONFIG_BIN"
    assert_platform_template
    assert_contains "$CASE_DIR/stderr" "checking php-config... $PHP_CONFIG_BIN"
    assert_contains "$(target_dir)/build.zig" "orelse \"$PHP_INCLUDE_DIR\""
    assert_not_contains "$(target_dir)/build.zig" "php-config"
    run_zig explicit-php-config-build-test build test
    run_php_ri explicit-php-config-ri
else
    note "explicit php-config + zig build test skipped"
fi

note "without run-tests"
new_case without_run_tests
run_skel \
    --ext demo_ext \
    --dir "$(php_path "$CASE_DIR/out")" \
    --phpz "$PHPZ_REF" \
    --without-run-tests
assert_no_path "$(target_dir)/tests"
assert_no_path "$(target_dir)/run-tests.php"
assert_platform_template
assert_not_contains "$(target_dir)/build.zig" "Run PHPT tests"
assert_not_contains "$(target_dir)/build.zig" "run-tests.php"
assert_not_contains "$(target_dir)/README.md" "zig build test"
run_zig without-run-tests-build build
run_php_ri without-run-tests-ri

note "without gen-stub + zig build test"
new_case without_gen_stub
run_skel \
    --ext demo_ext \
    --dir "$(php_path "$CASE_DIR/out")" \
    --phpz "$PHPZ_REF" \
    --without-gen-stub
assert_no_path "$(target_dir)/build/gen_stub.php"
assert_file "$(target_dir)/demo_ext_arginfo.h"
assert_dir "$(target_dir)/tests"
assert_platform_template
run_zig without-gen-stub-build-test build test
run_php_ri without-gen-stub-ri

note "ok"
