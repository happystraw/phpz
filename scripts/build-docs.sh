#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

php_include_dir=$(php-config --include-dir)
zig build docs -Dphp-include-dir="$php_include_dir"
npx --yes pagefind@1.6.0 --site docs/public/phpz
