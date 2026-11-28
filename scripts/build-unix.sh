#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'HELP'
Usage: build-unix.sh --php-version VERSION --target TARGET [OPTIONS] [-- ZIG_BUILD_ARGS...]

Build a shared PHP extension for Linux or macOS from its project directory.

  --php-version VERSION    Exact PHP release with published SDK assets (required)
  --target TARGET          {x86_64,aarch64}-{linux-gnu,linux-musl,macos} (required)
  --nts / --zts            PHP thread safety (default: nts)
  -h, --help               Show this help

Verified SDKs are cached under ${XDG_CACHE_HOME:-$HOME/.cache}/phpz/sdk.
Dependencies: zig, curl, tar, and sha256sum or shasum.

Examples:
  build-unix.sh --php-version 8.2.36 --target aarch64-linux-gnu --nts
  build-unix.sh --php-version 8.2.36 --target x86_64-macos --zts -- -Doptimize=ReleaseFast
HELP
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

version=
target=
ts=
while (( $# )); do
    case "$1" in
        --php-version|--target)
            [[ $# -ge 2 && "$2" != -* ]] || die "$1 requires a value"
            if [[ "$1" == --target ]]; then target=$2; else version=$2; fi
            shift 2 ;;
        --nts|--zts)
            [[ -z "$ts" || "$ts" == "${1#--}" ]] || die "choose either --nts or --zts"
            ts=${1#--}
            shift ;;
        --) shift; break ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1 (see --help)" ;;
    esac
done
ts=${ts:-nts}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "expected --php-version X.Y.Z"
[[ "$target" =~ ^(x86_64|aarch64)-(linux-gnu|linux-musl|macos)$ ]] || die "unsupported --target: $target"
arch=${target%%-*}
case "${target#*-}" in
    linux-gnu) platform=linux-$arch-glibc; legacy_target=$target.2.36 ;;
    linux-musl) platform=linux-$arch-musl; legacy_target=$target ;;
    macos) platform=macos-$arch; legacy_target=$target.15.0 ;;
esac
[[ -f build.zig && -f build.zig.zon ]] || die "run from the extension project directory"
for arg in "$@"; do
    case "$arg" in -Dtarget=*|-Dphp-include-dir=*) die "SDK selection already sets $arg" ;; esac
done

package=php-$version-$platform-$ts
archive=$package.tar.gz
cache=${XDG_CACHE_HOME:-$HOME/.cache}/phpz/sdk
mkdir -p "$cache"
cache=$(cd "$cache" && pwd -P)
sdk=$cache/$package
if [[ ! -d "$sdk" ]]; then
    url=https://github.com/happystraw/php-extension-sdk/releases/download/php-$version
    tmp=$(mktemp -d "$cache/.download.XXXXXXXX")
    trap 'rm -rf "$tmp"' EXIT
    for asset in SHA256SUMS "$archive"; do
        curl -fsSL --retry 3 "$url/$asset" -o "$tmp/$asset" || die "cannot download $package from $url/$asset"
    done
    (
        cd "$tmp"
        awk -v file="$archive" '$2 == file { print; matches++ } END { exit matches != 1 }' SHA256SUMS > checksum ||
            die "missing or duplicate checksum for $archive"
        if command -v sha256sum >/dev/null; then sha256sum -c checksum; else shasum -a 256 -c checksum; fi
        tar -xzf "$archive"
        [[ -f "$package/include/main/php.h" && -f "$package/build-info.txt" ]] || die "incomplete SDK: $archive"
        # A concurrent build may already have installed this same complete directory.
        mv "$package" "$cache/" || [[ -d "$sdk" ]]
    )
    rm -rf "$tmp"
    trap - EXIT
fi

zig_target=$(sed -n 's/^zig_target=//p' "$sdk/build-info.txt")
zig_target=${zig_target:-$legacy_target}
case "$zig_target" in
    "$target"|"$target".*) ;;
    *) die "SDK $package declares an incompatible Zig target: $zig_target" ;;
esac
printf 'Building %s with SDK %s\n' "$zig_target" "$package"
exec zig build "-Dtarget=$zig_target" "-Dphp-include-dir=$sdk/include" "$@"
