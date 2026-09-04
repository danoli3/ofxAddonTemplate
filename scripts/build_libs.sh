#!/usr/bin/env bash
#
# build_libs.sh - TEMPLATE for building addon libs and packaging them as
# GitHub release assets with the naming convention expected by
# scripts/download_libs.sh:
#
#   <addon-name>-libs-<platform>-<libs-version>.tar.bz2
#
# Usage:
#   scripts/build_libs.sh [platform] [-v <libs-version>]
#   scripts/build_libs.sh --upload [platform] [-v <libs-version>]  (needs `gh`)
#
# Steps for the addon author:
#   1. Set LIB_NAME / LIB_SRC / BUILD_CMDS below to build your lib.
#   2. Run this on each platform (or in CI), producing one archive per platform.
#   3. Create a GitHub release named <libs-version> and upload the archives:
#        gh release create 1.0.0 releases/*.tar.bz2
#   4. Point scripts/download_libs.sh at your repo (GITHUB_REPO) and version.
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$(dirname "$SCRIPT_DIR")"
ADDON_NAME="$(basename "$ADDON_DIR")"

# ---------------------------------------------------------------- TODO: edit
LIB_NAME="necessaryLib"   # folder under libs/ holding include/ src/ lib/
LIBS_VERSION="1.0.0"      # GitHub release tag the archives are uploaded to
RELEASE_DIR="$ADDON_DIR/releases"
# ----------------------------------------------------------------------------

PLATFORM=""
UPLOAD=0
while [ $# -gt 0 ]; do
    case "$1" in
        -v|--version) LIBS_VERSION="$2"; shift 2 ;;
        --upload) UPLOAD=1; shift ;;
        -h|--help) sed -n '2,/^$/p' "$0"; exit 0 ;;
        *) PLATFORM="$1"; shift ;;
    esac
done

if [ -z "$PLATFORM" ]; then
    # Same detection as download_libs.sh
    case "$(uname -s)" in
        Darwin) PLATFORM="osx" ;;
        MINGW*|MSYS*|CYGWIN*) PLATFORM="msys2" ;;
        Linux)
            case "$(uname -m)" in
                x86_64) PLATFORM="linux64" ;;
                armv6l) PLATFORM="linuxarmv6l" ;;
                armv7l) PLATFORM="linuxarmv7l" ;;
                aarch64) PLATFORM="linuxaarch64" ;;
                *) PLATFORM="linux64" ;;
            esac ;;
        *) PLATFORM="linux64" ;;
    esac
fi
if [ "$PLATFORM" = "macos" ]; then PLATFORM="osx"; fi

LIB_DIR="$ADDON_DIR/libs/$LIB_NAME"
OUT_DIR="$LIB_DIR/lib/$PLATFORM"

echo "==> TODO: build your lib here and install the binaries into:"
echo "    $OUT_DIR"
echo "    (edit the BUILD section of $0)"
# Example: build from libs/$LIB_NAME/src with cmake/make, then copy:
#   cmake -S "$LIB_DIR/src" -B "/tmp/${LIB_NAME}-build" -DCMAKE_BUILD_TYPE=Release
#   cmake --build "/tmp/${LIB_NAME}-build" --config Release
#   mkdir -p "$OUT_DIR"
#   cp "/tmp/${LIB_NAME}-build/libnecessaryLib.a" "$OUT_DIR/"

if [ ! -d "$OUT_DIR" ]; then
    echo "ERROR: $OUT_DIR does not exist. Build the lib for $PLATFORM first." >&2
    exit 1
fi

ASSET="${ADDON_NAME}-libs-${PLATFORM}-${LIBS_VERSION}.tar.bz2"
mkdir -p "$RELEASE_DIR"
# Archive paths relative to libs/$LIB_NAME so they extract to lib/<platform>/...
tar -cjf "$RELEASE_DIR/$ASSET" -C "$LIB_DIR" "lib/$PLATFORM" "include"
echo "==> wrote $RELEASE_DIR/$ASSET"
tar -tjf "$RELEASE_DIR/$ASSET" | head -n 20

if [ "$UPLOAD" = "1" ]; then
    gh release upload "$LIBS_VERSION" "$RELEASE_DIR/$ASSET" --clobber
fi

echo "Upload all platform archives with:"
echo "  gh release create $LIBS_VERSION $RELEASE_DIR/*.tar.bz2"
