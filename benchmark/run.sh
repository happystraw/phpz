#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
phpx_version=v2.9.8
phpx_commit=90e6d22a9c3f4d5dbd2c75d62e90bf5adfe58c89
phpx_checksum=948450b2fab433a1676b249853a25e4dd51df881ea3b504169f943e346dc27b9
php="$(command -v "${PHP:-php}")"
if [[ ${1:-} == --help ]]; then
    exec "$php" -n "$root/run.php" --help
fi

if [[ "$(uname -s)-$(uname -m)" != Linux-x86_64 ]]; then
    echo "This benchmark build targets Linux x86_64." >&2
    exit 1
fi

php_config="$(command -v "${PHP_CONFIG:-php-config}")"
cc="$(command -v "${CC:-cc}")"
cxx="$(command -v "${CXX:-c++}")"
zig="$(command -v "${ZIG:-zig}")"
jobs="${BENCH_JOBS:-4}"
if [[ "$("$php" -n -r 'echo PHP_VERSION_ID;')" != "$("$php_config" --vernum)" ]]; then
    echo "PHP and PHP_CONFIG must refer to the same PHP build." >&2
    exit 1
fi
"$php" -n -r 'exit(PHP_VERSION_ID >= 80400 && PHP_VERSION_ID < 80600 && !PHP_DEBUG && PHP_INT_SIZE === 8 ? 0 : 1);' || {
    echo "PHPX $phpx_version requires a 64-bit Release build of PHP 8.4 or 8.5 for this suite." >&2
    exit 1
}

build="$root/.build"
modules="$build/modules"
mkdir -p "$modules" "$build/bin"
exec 9>"$build/lock"
flock 9
ln -sfn "$php_config" "$build/bin/php-config"
export PATH="$build/bin:$PATH"

phpx_root="$build/phpx-$phpx_commit"
# The upstream build writes libphpx.so into its source directory.
abi="$("$php" -n -r 'printf("%d-%s", PHP_VERSION_ID, PHP_ZTS ? "zts" : "nts");')"
phpx_source="$phpx_root/$abi/source"
phpx_build="$phpx_root/$abi/build"
if [[ ! -f "$phpx_source/CMakeLists.txt" ]]; then
    mkdir -p "$phpx_root"
    phpx_archive="$phpx_root/source.tar.gz"
    if [[ ! -f "$phpx_archive" ]]; then
        curl --fail --location --silent --show-error --retry 2 \
            "https://codeload.github.com/swoole/phpx/tar.gz/$phpx_commit" -o "$phpx_archive.part"
        mv "$phpx_archive.part" "$phpx_archive"
    fi
    sha256sum --check --status <<< "$phpx_checksum  $phpx_archive" || {
        echo "PHPX source checksum mismatch at $phpx_archive." >&2
        exit 1
    }
    mkdir -p "$phpx_source"
    tar -xzf "$phpx_archive" -C "$phpx_source" --strip-components=1
fi
# PHPX matches the full mpdecimal source path. Limit the exclusion
# to benchmark filenames so a checkout under benchmark/ keeps library files.
sed -i 's@EXCLUDE REGEX "bench"@EXCLUDE REGEX "/bench[^/]*[.]c$"@' "$phpx_source/CMakeLists.txt"

read -r -a php_includes <<< "$("$php_config" --includes)"
native_arch=-march=native
native_flags=(-O3 "$native_arch" -DNDEBUG)
zig_flags=(-Doptimize=ReleaseFast -Dcpu=native)
echo "Building C extension" >&2
"$cc" "${native_flags[@]}" -DCOMPILE_DL_BENCH_C -fPIC -shared "${php_includes[@]}" \
    "$root/c/bench_c.c" -o "$modules/bench_c.so"

echo "Building PHPX library and extension" >&2
cmake -S "$phpx_source" -B "$phpx_build" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$cc" -DCMAKE_CXX_COMPILER="$cxx" \
    -DCMAKE_C_FLAGS="$native_arch" -DCMAKE_CXX_FLAGS="$native_arch" \
    -DCMAKE_C_FLAGS_RELEASE='-O3 -DNDEBUG' -DCMAKE_CXX_FLAGS_RELEASE='-O3 -DNDEBUG' \
    -DBUILD_EXT=OFF -DBUILD_TESTS=OFF
cmake --build "$phpx_build" --parallel "$jobs"
"$cxx" "${native_flags[@]}" -std=c++17 -fPIC -shared "${php_includes[@]}" \
    -I"$phpx_source/include" "$root/cpp/bench_phpx.cpp" \
    -L"$phpx_source/lib" -Wl,-rpath,"$phpx_source/lib" -lphpx -o "$modules/bench_phpx.so"

echo "Building PHPZ extension" >&2
(
    cd "$root/zig"
    export ZIG_GLOBAL_CACHE_DIR="${ZIG_GLOBAL_CACHE_DIR:-$build/zig-global-cache}"
    export ZIG_LOCAL_PKG_DIR="${ZIG_LOCAL_PKG_DIR:-$root/../zig-pkg}"
    "$zig" build -j"$jobs" "${zig_flags[@]}" \
        -Dphp-include-dir="$("$php_config" --include-dir)"
)
cp "$root/zig/modules/bench_zig.so" "$modules/bench_zig.so"

# Use one allowed logical CPU for the parent and every child.
cpu="${BENCH_CPU:-$(LC_ALL=C taskset -pc "$$" | awk '{print $NF}' | cut -d, -f1 | cut -d- -f1)}"
export BENCH_CPU="$cpu" BENCH_MODULES="$modules"
BENCH_COMMIT="$(git -C "$root" rev-parse HEAD)" \
BENCH_DIRTY="$(git -C "$root" status --porcelain -- . ../src ../build ../build.zig ../build.zig.zon)" \
BENCH_CC="$("$cc" --version | sed -n '1p')" \
BENCH_CXX="$("$cxx" --version | sed -n '1p')" \
BENCH_ZIG="$("$zig" version)" BENCH_PHPX_VERSION="$phpx_version" BENCH_PHPX_COMMIT="$phpx_commit" \
BENCH_PHP_CONFIG="$php_config" \
BENCH_NATIVE_FLAGS="${native_flags[*]}" BENCH_ZIG_FLAGS="${zig_flags[*]} (LTO disabled)" \
    "$php" -n -r '
        $metadata = [
            "commit" => getenv("BENCH_COMMIT"), "dirty" => getenv("BENCH_DIRTY") !== "",
            "phpx_library_sha256" => hash_file("sha256", $argv[1]),
            "cc" => getenv("BENCH_CC"), "cxx" => getenv("BENCH_CXX"),
            "zig" => getenv("BENCH_ZIG"),
            "phpx_version" => getenv("BENCH_PHPX_VERSION"), "phpx_commit" => getenv("BENCH_PHPX_COMMIT"),
            "php_config" => getenv("BENCH_PHP_CONFIG"), "php_binary" => PHP_BINARY,
            "native_flags" => getenv("BENCH_NATIVE_FLAGS"),
            "zig_flags" => getenv("BENCH_ZIG_FLAGS"),
            "module_sha256" => [],
        ];
        foreach (["c", "phpx", "zig"] as $implementation) {
            $metadata["module_sha256"][$implementation] =
                hash_file("sha256", getenv("BENCH_MODULES") . "/bench_$implementation.so");
        }
        echo json_encode($metadata, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR), PHP_EOL;
    ' "$phpx_source/lib/libphpx.so" > "$modules/build.json"

exec taskset -c "$cpu" "$php" -n -d opcache.enable_cli=0 -d opcache.jit=disable "$root/run.php" "$@"
