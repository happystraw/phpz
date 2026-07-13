#!/usr/bin/env sh
set -eu

root_dir=$(cd "$(dirname "$0")/.." && pwd)
cd "$root_dir"

usage() {
    echo "usage: $0 [--php-version VERSION] [--zts]"
}

php_version=8.5.8
php_thread_safety=nts

while [ "$#" -gt 0 ]; do
    case "$1" in
    --php-version)
        if [ "$#" -lt 2 ]; then
            usage >&2
            exit 2
        fi
        php_version=$2
        shift 2
        ;;
    --zts)
        php_thread_safety=zts
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
    esac
done

# Match the Visual Studio toolset used by official PHP for Windows builds.
case "$php_version" in
8.2.* | 8.3.*)
    vs_version=16
    ;;
8.4.* | 8.5.*)
    vs_version=17
    ;;
8.6.*)
    vs_version=18
    ;;
*)
    echo "unsupported PHP version: $php_version (supported: 8.2-8.6)" >&2
    exit 2
    ;;
esac
vs_toolset=vs$vs_version

tmp_dir=$root_dir/tmp
xwin=$tmp_dir/xwin
win_sdk=$tmp_dir/win_sdk-$vs_toolset
libc_file=$tmp_dir/libc-$vs_toolset.txt

case "$php_thread_safety" in
nts)
    php_archive_name=php-devel-pack-${php_version}-nts-Win32-${vs_toolset}-x64.zip
    ;;
zts)
    php_archive_name=php-devel-pack-${php_version}-Win32-${vs_toolset}-x64.zip
    ;;
*)
    usage >&2
    exit 2
    ;;
esac

php_cache_dir=$tmp_dir/php-${php_version}-${php_thread_safety}
php_sdk=$php_cache_dir/php-${php_version}-devel-${vs_toolset}-x64

mkdir -p "$tmp_dir"

echo "==> Preparing xwin"
if [ ! -x "$xwin" ]; then
    xwin_archive=$tmp_dir/xwin-0.9.0-x86_64-unknown-linux-musl.tar.gz
    curl -fsSL \
        https://github.com/Jake-Shadle/xwin/releases/download/0.9.0/xwin-0.9.0-x86_64-unknown-linux-musl.tar.gz \
        -o "$xwin_archive"
    tar -xzf "$xwin_archive" \
        -C "$tmp_dir" \
        --strip-components=1 \
        xwin-0.9.0-x86_64-unknown-linux-musl/xwin
    rm "$xwin_archive"
fi

echo "==> Preparing Windows SDK and MSVC toolset ($vs_toolset)"
if [ ! -d "$win_sdk" ]; then
    "$xwin" \
        --accept-license \
        --manifest-version "$vs_version" \
        --arch x86_64 \
        --variant desktop \
        --cache-dir "$HOME/.cache/xwin/$vs_toolset" \
        splat \
        --include-debug-libs \
        --include-debug-symbols \
        --preserve-ms-arch-notation \
        --output "$win_sdk"
fi

if [ ! -e "$win_sdk/sdk/include/um/Ws2tcpip.h" ]; then
    ln -s WS2tcpip.h "$win_sdk/sdk/include/um/Ws2tcpip.h"
fi

php_archive=$tmp_dir/$php_archive_name
echo "==> Preparing PHP $php_version development files ($php_thread_safety, $vs_toolset)"
if [ ! -d "$php_sdk" ]; then
    curl -fsSL \
        "https://downloads.php.net/~windows/releases/archives/$php_archive_name" \
        -o "$php_archive"
    mkdir -p "$php_cache_dir"
    unzip -q "$php_archive" -d "$php_cache_dir"
    rm "$php_archive"
fi

echo "==> Writing Zig libc configuration ($libc_file)"
cat >"$libc_file" <<EOF
include_dir=$win_sdk/sdk/include/ucrt
sys_include_dir=$win_sdk/crt/include
crt_dir=$win_sdk/sdk/lib/ucrt/x64
msvc_lib_dir=$win_sdk/crt/lib/x64
kernel32_lib_dir=$win_sdk/sdk/lib/um/x64
gcc_dir=
EOF

set -- -Dtarget=native-windows-msvc \
    -Dlibc-file="$libc_file" \
    -Dphp-include-dir="$php_sdk/include" \
    -Dphp-lib-dir="$php_sdk/lib"

if [ "$php_thread_safety" = zts ]; then
    set -- "$@" -Dwindows-zts=true
fi

echo "==> Running phpz tests"
zig build test "$@"

echo "==> Building skeleton example"
(
    cd examples/skeleton
    zig build "$@"
)

echo "==> Building my_php_extension example"
(
    cd examples/my_php_extension
    zig build "$@"
)
