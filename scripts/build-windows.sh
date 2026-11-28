#!/usr/bin/env sh
set -eu

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [-- ZIG_BUILD_ARGS...]

Cross-compile the current PHPZ project on Linux for Windows x86_64 MSVC.

  --php-version VERSION    PHP version (default: 8.6.0; supported: 8.2-8.6, including alpha/beta/RC)
  --nts / --zts            PHP thread safety (default: nts)
  --xwin-version VERSION   xwin release version (default: 0.10.0)
  --xwin-cache-dir PATH    xwin cache root (default: \${XDG_CACHE_HOME:-\$HOME/.cache}/xwin)
  -h, --help               Show this help

Projects share prepared SDKs under \${XDG_CACHE_HOME:-\$HOME/.cache}/phpz/windows/linux.
Dependencies: zig, curl, tar, unzip, flock, and standard shell utilities.
Preparing the Windows SDK accepts Microsoft's license through xwin.

Examples:
  $0 --php-version 8.6.0 --nts
  $0 --php-version 8.5.13 --zts -- -Doptimize=ReleaseFast
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}
arg_error() {
    echo "error: $*" >&2
    exit 2
}
require_value() {
    [ "$#" -ge 2 ] && [ -n "$2" ] || arg_error "$1 requires a value"
    case "$2" in --*) arg_error "$1 requires a value" ;; esac
}

php_version=8.6.0
php_thread_safety=
xwin_version=0.10.0
xwin_cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/xwin
target_arch=x86_64
ms_arch=x64

while [ "$#" -gt 0 ]; do
    case "$1" in
    --php-version)
        require_value "$@"
        php_version=$2
        shift 2
        ;;
    --xwin-version)
        require_value "$@"
        xwin_version=$2
        shift 2
        ;;
    --xwin-cache-dir)
        require_value "$@"
        xwin_cache_dir=$2
        shift 2
        ;;
    --nts | --zts)
        [ -z "$php_thread_safety" ] || [ "$php_thread_safety" = "${1#--}" ] ||
            arg_error "choose either --nts or --zts"
        php_thread_safety=${1#--}
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    --)
        shift
        break
        ;;
    *) arg_error "unknown option: $1 (see --help)" ;;
    esac
done
php_thread_safety=${php_thread_safety:-nts}

printf '%s\n' "$php_version" | grep -Eq '^8\.[2-6]\.[0-9]+((alpha|beta|RC)[0-9]+)?$' ||
    arg_error "unsupported PHP version: $php_version (expected 8.2-8.6 major.minor.patch with optional alpha/beta/RC suffix)"
printf '%s\n' "$xwin_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' ||
    arg_error "invalid xwin version: $xwin_version (expected major.minor.patch)"

[ "$(uname -s)" = Linux ] || die "only Linux hosts are supported"
host_arch=$(uname -m)
case "$host_arch" in x86_64 | aarch64) ;; *) die "unsupported Linux host architecture: $host_arch" ;; esac
for arg in "$@"; do
    case "$arg" in
    -Dtarget=*|-Dphp-include-dir=*|-Dphp-lib-dir=*|-Dlibc-file=*|-Dwindows-zts=*|-Dwindows-debug=*)
        arg_error "SDK selection already sets $arg" ;;
    esac
done
project_dir=$(pwd -P)
[ -f "$project_dir/build.zig" ] && [ -f "$project_dir/build.zig.zon" ] ||
    die "current directory must contain build.zig and build.zig.zon: $project_dir"
for dependency in zig curl tar unzip flock; do
    command -v "$dependency" >/dev/null 2>&1 || die "required command not found: $dependency"
done

case "$php_version" in
8.2.* | 8.3.*) vs_version=16 ;;
8.4.* | 8.5.*) vs_version=17 ;;
8.6.*) vs_version=18 ;;
esac
vs_toolset=vs$vs_version
cache_root=${XDG_CACHE_HOME:-$HOME/.cache}/phpz/windows/linux
mkdir -p "$cache_root/tmp"
cache_root=$(cd "$cache_root" && pwd -P)
run_tmp=$(mktemp -d "$cache_root/tmp/run.XXXXXX")
trap 'rm -rf -- "$run_tmp"' 0
trap 'exit 130' INT
trap 'exit 143' TERM
TMPDIR=$run_tmp
TMP=$run_tmp
TEMP=$run_tmp
export TMPDIR TMP TEMP

sdk_key=$xwin_version/$vs_toolset/$target_arch
tool_dir=$cache_root/tools/xwin/$xwin_version/linux-$host_arch
xwin=$tool_dir/xwin
win_sdk=$cache_root/sdk/$sdk_key
libc_file=$cache_root/config/$sdk_key/libc.txt
download_dir=$cache_root/downloads
mkdir -p "$download_dir" "$(dirname "$libc_file")"
printf '[INFO] Project: %s\n[INFO] PHP: %s %s (%s); xwin: %s\n[INFO] Cache: %s\n' \
    "$project_dir" "$php_version" "$php_thread_safety" "$vs_toolset" "$xwin_version" "$cache_root"

download() {
    # Publish only successful downloads; partial files remain in this run's tmp.
    printf '[INFO] Downloading: %s\n' "$1"
    curl --fail --location --silent --show-error --retry 2 --connect-timeout 20 \
        "$1" -o "$run_tmp/download.part" || return 1
    mv "$run_tmp/download.part" "$2"
}

# Serialize cache preparation across projects, then let Zig builds run concurrently.
exec 9>"$cache_root/prepare.lock"
flock -x 9

php_cache=$cache_root/php/$php_version/$php_thread_safety/$target_arch
sdk_name=php-$php_version-devel-$vs_toolset-$ms_arch
php_sdk=$php_cache/$sdk_name
case "$php_thread_safety" in
nts) thread_suffix=-nts; import_lib=php8.lib ;;
zts) thread_suffix=; import_lib=php8ts.lib ;;
esac
valid_php_sdk() {
    [ -f "$1/include/main/php.h" ] && [ -s "$1/include/main/php.h" ] &&
        [ -f "$1/lib/$import_lib" ] && [ -s "$1/lib/$import_lib" ]
}
if [ ! -f "$php_cache/.complete" ] || ! valid_php_sdk "$php_sdk"; then
    archive_name=php-devel-pack-$php_version$thread_suffix-Win32-$vs_toolset-$ms_arch.zip
    archive=$download_dir/$archive_name
    case "$php_version" in
    *alpha* | *beta* | *RC*) base=https://downloads.php.net/~windows/qa ;;
    *) base=https://downloads.php.net/~windows/releases/archives ;;
    esac
    for attempt in 1 2; do
        if [ ! -f "$archive" ]; then
            download "$base/$archive_name" "$archive" ||
                die "PHP development pack unavailable: $archive_name"
        fi
        mkdir -p "$run_tmp/php"
        if unzip -q "$archive" -d "$run_tmp/php" && valid_php_sdk "$run_tmp/php/$sdk_name"; then
            break
        fi
        rm -f -- "$archive"
        rm -rf -- "$run_tmp/php"
        [ "$attempt" -eq 1 ] || die "Invalid PHP development pack after retry: $archive_name"
        echo "[WARN] Invalid PHP development pack; downloading $archive_name again" >&2
    done
    touch "$run_tmp/php/.complete"
    mkdir -p "$(dirname "$php_cache")"
    rm -rf -- "$php_cache"
    mv "$run_tmp/php" "$php_cache"
fi
echo "[INFO] PHP SDK: $php_sdk"

if [ ! -f "$tool_dir/.complete" ] || [ ! -x "$xwin" ]; then
    package=xwin-$xwin_version-$host_arch-unknown-linux-musl
    archive=$download_dir/$package.tar.gz
    base=https://github.com/Jake-Shadle/xwin/releases/download/$xwin_version
    [ -f "$archive" ] || download "$base/$package.tar.gz" "$archive"
    mkdir -p "$run_tmp/tool"
    if ! tar -xzf "$archive" -C "$run_tmp/tool" --strip-components=1 "$package/xwin"; then
        rm -f -- "$archive"
        die "Cannot extract $package; the next build will download it again"
    fi
    touch "$run_tmp/tool/.complete"
    mkdir -p "$(dirname "$tool_dir")"
    rm -rf -- "$tool_dir"
    mv "$run_tmp/tool" "$tool_dir"
fi

if [ ! -f "$win_sdk/.complete" ]; then
    echo "[INFO] Preparing Windows SDK and MSVC ($vs_toolset)"
    "$xwin" --accept-license --manifest-version "$vs_version" --arch "$target_arch" \
        --variant desktop --cache-dir "$xwin_cache_dir/$sdk_key" \
        splat --copy --include-debug-libs --include-debug-symbols --preserve-ms-arch-notation \
        --output "$run_tmp/sdk"
    touch "$run_tmp/sdk/.complete"
    mkdir -p "$(dirname "$win_sdk")"
    rm -rf -- "$win_sdk"
    mv "$run_tmp/sdk" "$win_sdk"
fi

# Fix header spelling for both newly prepared and cached SDKs.
if [ ! -e "$win_sdk/sdk/include/um/Ws2tcpip.h" ] && [ -f "$win_sdk/sdk/include/um/WS2tcpip.h" ]; then
    ln -s WS2tcpip.h "$win_sdk/sdk/include/um/Ws2tcpip.h"
fi
if [ ! -e "$win_sdk/sdk/include/um/Winsock2.h" ] && [ -f "$win_sdk/sdk/include/um/WinSock2.h" ]; then
    ln -s WinSock2.h "$win_sdk/sdk/include/um/Winsock2.h"
fi

cat >"$run_tmp/libc.txt" <<EOF
include_dir=$win_sdk/sdk/include/ucrt
sys_include_dir=$win_sdk/crt/include
crt_dir=$win_sdk/sdk/lib/ucrt/$ms_arch
msvc_lib_dir=$win_sdk/crt/lib/$ms_arch
kernel32_lib_dir=$win_sdk/sdk/lib/um/$ms_arch
cc_dir=
darwin_sdk_dir=
EOF
if ! cmp -s "$run_tmp/libc.txt" "$libc_file"; then
    mv "$run_tmp/libc.txt" "$libc_file"
fi
flock -u 9
exec 9>&-

windows_zts=false
[ "$php_thread_safety" != zts ] || windows_zts=true
printf "\nBuilding %s-windows-msvc\n" $target_arch
(
    set -x
    zig build -Dtarget="$target_arch-windows-msvc" -Dlibc-file="$libc_file" \
        -Dphp-include-dir="$php_sdk/include" -Dphp-lib-dir="$php_sdk/lib" \
        -Dwindows-zts="$windows_zts" -Dwindows-debug=false "$@"
)
printf "\nBuild completed\n"
