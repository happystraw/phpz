#!/usr/bin/env sh
set -eu

root_dir=$(cd "$(dirname "$0")/.." && pwd)
build_windows=$root_dir/scripts/build-windows.sh

case "${1-}" in
-h | --help) exec "$build_windows" --help ;;
esac

run_phpz_tests() {
    test_step_added=false
    # Insert the test step after the first --, preserving argument order.
    for arg; do
        shift
        set -- "$@" "$arg"
        if [ "$arg" = -- ] && [ "$test_step_added" = false ]; then
            set -- "$@" test
            test_step_added=true
        fi
    done
    if [ "$test_step_added" = false ]; then
        set -- "$@" -- test
    fi
    "$build_windows" "$@"
}

cd "$root_dir"
echo "------------------------------------"
echo "Running phpz tests"
echo "------------------------------------"
run_phpz_tests "$@"

for example in skeleton my_php_extension; do
    echo "------------------------------------"
    echo "Building $example example"
    echo "------------------------------------"
    (
        cd "$root_dir/examples/$example"
        "$build_windows" "$@"
    )
done
