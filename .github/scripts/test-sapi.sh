#!/usr/bin/env bash
# Build external PHP libraries and test each SAPI configuration in one job.
set -eo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
case "$(uname -s)" in
    Linux) system=Linux; jobs=$(getconf _NPROCESSORS_ONLN) ;;
    Darwin) system=Darwin; jobs=$(sysctl -n hw.ncpu) ;;
    MINGW*|MSYS*|CYGWIN*)
        system=Windows
        jobs=${NUMBER_OF_PROCESSORS:-2}
        # Native PHP, PowerShell and Zig need Windows paths, including env vars.
        repo=$(cygpath -m "$repo")
        # In particular, do not rewrite dumpbin's /dependents switch as a path.
        export MSYS_NO_PATHCONV=1
        ;;
    *) echo 'Unsupported SAPI test platform' >&2; exit 1 ;;
esac
example="$repo/examples/custom_sapi"
work="$repo/build/sapi-tests"
spc="$repo/build/spc"
php=$(command -v php)
zig=$(command -v zig)
export PHP_BUILD_VERSION=${PHP_BUILD_VERSION:-8.5}

run() {
    printf '+ ' >&2
    printf '%q ' "$@" >&2
    printf '\n' >&2
    "$@"
}

test_configuration() {
    local linkage=$1 ts=$2 build_type=$3
    local case_dir="$work/$linkage-$ts-$build_type"
    local include lib source flags name binary runtime='' key value
    local zts=false debug=false shared=true i php_major php_minor
    local extra=() command=() dependencies=()
    export PHP_BUILD_TS=$ts PHP_BUILD_DEBUG=0
    if [[ $ts == ts ]]; then zts=true; fi
    if [[ $build_type == debug ]]; then debug=true; export PHP_BUILD_DEBUG=1; fi

    if [[ $linkage == static ]]; then
        shared=false
        export BUILD_ROOT_PATH="$case_dir/buildroot" SOURCE_PATH="$case_dir/source"
        export SPC_LOGS_DIR="$case_dir/spc-logs" SPC_CONCURRENCY=$jobs
        if [[ $system == Linux ]]; then
            export SPC_TARGET=x86_64-linux-musl
            extra+=(-Dtarget=x86_64-linux-musl)
        fi
        command=("$php" "$spc/bin/spc" build:php bcmath --build-embed
            --disable-opcache-jit "--dl-with-php=$PHP_BUILD_VERSION" --no-interaction --no-ansi)
        if [[ $ts == ts ]]; then command+=(--enable-zts); fi
        cd "$spc"
        run "${command[@]}"
        flags=$(run "$php" "$spc/bin/spc" spc-config bcmath --with-packages=php --libs-only-deps --no-ansi)
        # SPC's short library names have no spaces; never evaluate linker output.
        flags=${flags//$'\r'/}
        flags=${flags//$'\n'/ }
        read -r -a dependencies <<< "$flags"
        for ((i=0; i<${#dependencies[@]}; i++)); do
            name=${dependencies[i]}
            case "$name" in
                -framework)
                    i=$((i + 1))
                    if [[ -z ${dependencies[i]} || ${dependencies[i]} == -* ]]; then
                        echo 'Missing SPC framework name' >&2; return 1
                    fi
                    extra+=("-Dlink-framework=${dependencies[i]}")
                    ;;
                -l?*) extra+=("-Dlink-lib=${name#-l}") ;;
                *)
                    if [[ $name =~ ^[[:alnum:]_.-]+\.lib$ ]]; then
                        extra+=("-Dlink-lib=${name%.lib}")
                    else
                        echo "Unsupported SPC link argument: $name" >&2; return 1
                    fi
                    ;;
            esac
        done
        include="$BUILD_ROOT_PATH/include/php"
        lib="$BUILD_ROOT_PATH/lib"
        if [[ $system == Windows ]]; then
            include="$SOURCE_PATH/php-src"
            for name in kernel32 ole32 user32 advapi32 shell32 ws2_32 dnsapi psapi bcrypt pathcch secur32 crypt32 gdi32; do
                extra+=("-Dlink-lib=$name")
            done
            IFS=. read -r php_major php_minor <<< "$PHP_BUILD_VERSION"
            if ((php_major > 8 || (php_major == 8 && php_minor >= 5))); then
                # Retain the static definitions imported by PHP's URI code.
                extra+=(-Dforce-undefined-symbol=lxb_url_parse -Dforce-undefined-symbol=lxb_unicode_idna_init)
            fi
        fi
    elif [[ $system == Windows ]]; then
        GITHUB_ENV="$case_dir/github-env.txt" GITHUB_PATH="$case_dir/github-path.txt" \
            run pwsh -NoProfile -File "$repo/.github/scripts/setup-php-windows.ps1" \
                -PhpVersion "$PHP_BUILD_VERSION" -Arch x64 -ThreadSafety "$ts" -Destination "$case_dir/sdk"
        while IFS='=' read -r key value; do
            key=${key#$'\xef\xbb\xbf'}
            value=${value%$'\r'}
            case "$key" in
                PHP_INCLUDE_DIR) include=$(cygpath -m "$value") ;;
                PHP_LIB_DIR) lib=$(cygpath -m "$value") ;;
                PHP_BIN_DIR) runtime=$(cygpath -m "$value") ;;
                LIBC_FILE) extra+=("-Dlibc-file=$(cygpath -m "$value")") ;;
            esac
        done < "$case_dir/github-env.txt"
        [[ -n $include && -n $lib && -n $runtime ]]
    else
        source="$case_dir/php-src"
        mkdir -p "$source"
        tar -C "$repo/build/php-src" --exclude=.git -cf - . | tar -C "$source" -xf -
        cd "$source"
        command=(./configure --disable-all --disable-cli --disable-cgi --disable-phpdbg --enable-embed=shared)
        if [[ $ts == ts ]]; then command+=(--enable-zts); else command+=(--disable-zts); fi
        if [[ $build_type == debug ]]; then command+=(--enable-debug); else command+=(--disable-debug); fi
        run "${command[@]}"
        run make "-j$jobs"
        include=$source
        lib="$source/libs"
    fi

    binary="$case_dir/out/bin/custom-sapi"
    if [[ $system == Windows ]]; then
        extra+=(-Dtarget=x86_64-windows-msvc "-Dwindows-zts=$zts" "-Dwindows-debug=$debug")
        binary+=.exe
    fi
    cd "$example"
    run "$zig" build -Doptimize=ReleaseSafe "-Dshared=$shared" \
        "-Dphp-include-dir=$include" "-Dphp-lib-dir=$lib" --prefix "$case_dir/out" "${extra[@]}"
    if [[ -n $runtime ]]; then cp "$runtime/"*.dll "$(dirname "$binary")/"; fi

    local pattern actual=static
    case "$system" in
        Windows) run dumpbin /dependents "$binary" > "$case_dir/linkage.log"; pattern='php[0-9]+(ts)?(_debug)?\.dll' ;;
        Darwin) run otool -L "$binary" > "$case_dir/linkage.log"; pattern='libphp[^/[:space:]]*\.dylib' ;;
        Linux) run readelf -d "$binary" > "$case_dir/linkage.log"; pattern='\(NEEDED\).*\[libphp[^]]*\.so[^]]*\]' ;;
    esac
    cat "$case_dir/linkage.log"
    if grep -Ei "$pattern" "$case_dir/linkage.log" > /dev/null; then actual=dynamic; fi
    if [[ $actual != "$linkage" ]]; then
        echo "PHP linkage mismatch: expected $linkage, got $actual" >&2; return 1
    fi
    run "$php" -n "$example/tests/run.php" "$binary"
}

# A separate Bash process preserves errexit while the parent collects failures.
if [[ ${1:-} == --case && $# == 4 ]]; then
    test_configuration "$2" "$3" "$4"
    exit 0
fi

combinations=(dynamic-nts-nodebug dynamic-ts-nodebug static-nts-nodebug static-ts-nodebug)
if [[ $system == Linux ]]; then combinations+=(dynamic-nts-debug dynamic-ts-debug); fi
mkdir -p "$work"
printf '| Linkage | Thread safety | PHP build | Result |\n| --- | --- | --- | --- |\n' > "$work/results.md"
failed=()
for name in "${combinations[@]}"; do
    IFS=- read -r linkage ts build_type <<< "$name"
    case_dir="$work/$name"
    printf '::group::%s\n' "$name"
    rm -rf "$case_dir"
    mkdir -p "$case_dir"
    if bash "$repo/.github/scripts/test-sapi.sh" --case "$linkage" "$ts" "$build_type" > "$case_dir/test.log" 2>&1; then
        result=PASS
    else
        result=FAIL
        failed+=("$name")
        tail -c 16000 "$case_dir/test.log"
    fi
    printf '\n::endgroup::\n%s %s\n' "$result" "$name"
    printf '| %s | %s | %s | %s |\n' "$linkage" "$ts" "$build_type" "$result" >> "$work/results.md"
done
if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then cat "$work/results.md" >> "$GITHUB_STEP_SUMMARY"; fi
if ((${#failed[@]})); then
    printf 'Failed SAPI configurations: %s\n' "${failed[*]}" >&2
    exit 1
fi
