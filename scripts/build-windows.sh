#!/usr/bin/env sh
set -eu

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [-- ZIG_BUILD_ARGS...]

Cross-compile the current PHPZ project on Linux for Windows x86_64 MSVC.

  --php-version VERSION    PHP version (default: 8.5.10; supported: 8.2-8.6)
  --nts / --zts            PHP thread safety (default: nts)
  --xwin-version VERSION   xwin release version (default: 0.10.0)
  --xwin-cache-dir PATH    xwin cache root (default: \${XDG_CACHE_HOME:-\$HOME/.cache}/xwin)
  -h, --help               Show this help

Project downloads, SDKs and temporary files live in ./build/windows/.
Dependencies: zig, curl, tar, unzip, and standard shell utilities.
Preparing the Windows SDK accepts Microsoft's license through xwin.

Examples:
  $0 --php-version 8.5.10 --nts
  $0 --php-version 8.5.10 --zts
  $0 -- -Doptimize=ReleaseFast
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

php_version=8.5.10
php_thread_safety=nts
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

printf '%s\n' "$php_version" | grep -Eq '^8\.[2-6]\.[0-9]+$' ||
    arg_error "unsupported PHP version: $php_version (expected stable 8.2-8.6 major.minor.patch)"
printf '%s\n' "$xwin_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' ||
    arg_error "invalid xwin version: $xwin_version (expected major.minor.patch)"

[ "$(uname -s)" = Linux ] || die "only Linux hosts are supported"
host_arch=$(uname -m)
case "$host_arch" in x86_64 | aarch64) ;; *) die "unsupported Linux host architecture: $host_arch" ;; esac
project_dir=$(pwd -P)
[ -f "$project_dir/build.zig" ] && [ -f "$project_dir/build.zig.zon" ] ||
    die "current directory must contain build.zig and build.zig.zon: $project_dir"
for dependency in zig curl tar unzip; do
    command -v "$dependency" >/dev/null 2>&1 || die "required command not found: $dependency"
done

case "$php_version" in
8.2.* | 8.3.*) vs_version=16 ;;
8.4.* | 8.5.*) vs_version=17 ;;
8.6.*) vs_version=18 ;;
esac
vs_toolset=vs$vs_version
cache_root=$project_dir/build/windows
mkdir -p "$cache_root/tmp"
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

php_cache=$cache_root/php/$php_version/$php_thread_safety/$target_arch
php_sdk=$php_cache/php-$php_version-devel-$vs_toolset-$ms_arch
if [ ! -f "$php_cache/.complete" ]; then
    thread_suffix=
    [ "$php_thread_safety" != nts ] || thread_suffix=-nts
    archive_name=php-devel-pack-$php_version$thread_suffix-Win32-$vs_toolset-$ms_arch.zip
    archive=$download_dir/$archive_name
    if [ ! -f "$archive" ]; then
        base=https://downloads.php.net/~windows/releases
        download "$base/archives/$archive_name" "$archive" ||
            die "PHP development pack unavailable: $archive_name"
    fi
    mkdir -p "$run_tmp/php"
    unzip -q "$archive" -d "$run_tmp/php"
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
    tar -xzf "$archive" -C "$run_tmp/tool" --strip-components=1 "$package/xwin"
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

cat >"$libc_file" <<EOF
include_dir=$win_sdk/sdk/include/ucrt
sys_include_dir=$win_sdk/crt/include
crt_dir=$win_sdk/sdk/lib/ucrt/$ms_arch
msvc_lib_dir=$win_sdk/crt/lib/$ms_arch
kernel32_lib_dir=$win_sdk/sdk/lib/um/$ms_arch
gcc_dir=
EOF

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
