#!/usr/bin/env bash
# Package addon binaries built by the author.
# Usage: scripts/build_libs.sh [platform] [-v version] [--upload] [-u user/repo]
# Archives contain include/ and lib/<platform>/ relative to libs/<LIB_NAME>.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/libs_common.sh"
PLATFORM=""
UPLOAD=0
while [ $# -gt 0 ]; do
    case "$1" in
        -v|--version) require_value "$@"; LIBS_VERSION="$2"; shift 2 ;;
        -u|--repo) require_value "$@"; GITHUB_REPO="$2"; shift 2 ;;
        --upload) UPLOAD=1; shift ;;
        -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
        -*) fail "Unknown option: $1" ;;
        *) [ -z "$PLATFORM" ] || fail "Specify only one platform"; PLATFORM="$1"; shift ;;
    esac
done
validate_platform
LIB_DIR="$ADDON_DIR/libs/$LIB_NAME"
OUT_DIR="$LIB_DIR/lib/$PLATFORM"
RELEASE_DIR="$ADDON_DIR/releases"

# TODO: build your library here and install binaries in OUT_DIR.
# For example:
#   cmake -S "$LIB_DIR/src" -B "$ADDON_DIR/build/$PLATFORM" -DCMAKE_BUILD_TYPE=Release
#   cmake --build "$ADDON_DIR/build/$PLATFORM" --config Release
#   mkdir -p "$OUT_DIR"
#   cp "$ADDON_DIR/build/$PLATFORM/libnecessaryLib.a" "$OUT_DIR/"
[ -d "$OUT_DIR" ] || fail "Build your library into $OUT_DIR first"
BINARY="$(find "$OUT_DIR" -type f -size +0c ! -name '.gitkeep' ! -name '*.md' -print -quit)"
[ -n "$BINARY" ] || fail "No built binaries in $OUT_DIR (the template only supplies .gitkeep)"
[ -d "$LIB_DIR/include" ] || fail "Missing headers: $LIB_DIR/include"
ASSET="$(release_asset_name "$PLATFORM")"
mkdir -p "$RELEASE_DIR"
TEMP_ARCHIVE="$(mktemp "$RELEASE_DIR/.package.XXXXXX")"
trap 'rm -f "$TEMP_ARCHIVE"' EXIT
# Do not publish the skeleton markers as library files.
tar --exclude='.gitkeep' -cjf "$TEMP_ARCHIVE" -C "$LIB_DIR" "lib/$PLATFORM" include
mv "$TEMP_ARCHIVE" "$RELEASE_DIR/$ASSET"
echo "==> wrote $RELEASE_DIR/$ASSET"
if [ "$UPLOAD" = 1 ]; then
    gh release upload "$LIBS_VERSION" "$RELEASE_DIR/$ASSET" --repo "$GITHUB_REPO" --clobber
fi
