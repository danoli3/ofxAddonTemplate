#!/usr/bin/env bash
# Download addon binaries from GitHub releases.
# Usage: scripts/download_libs.sh [platform|all] [-v version] [-u user/repo]
# Configure scripts/libs_common.sh and scripts/libs_version.txt first.
# Archives: <addon-folder>-libs-<platform>-<version>.tar.bz2
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/libs_common.sh"
PLATFORM=""
ALLOW_ALL=1
while [ $# -gt 0 ]; do
    case "$1" in
        -v|--version) require_value "$@"; LIBS_VERSION="$2"; shift 2 ;;
        -u|--repo) require_value "$@"; GITHUB_REPO="$2"; shift 2 ;;
        -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
        -*) fail "Unknown option: $1" ;;
        *) [ -z "$PLATFORM" ] || fail "Specify only one platform"; PLATFORM="$1"; shift ;;
    esac
done
validate_platform
[[ "$GITHUB_REPO" != yournamehere/* ]] || fail "Configure GITHUB_REPO in scripts/libs_common.sh or pass -u user/repo"
[[ "$GITHUB_REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "Invalid GitHub repository: $GITHUB_REPO"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/addon-libs.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

download_one() {
    local platform="$1"
    local asset="${ADDON_NAME}-libs-${platform}-${LIBS_VERSION}.tar.bz2"
    local url="https://github.com/${GITHUB_REPO}/releases/download/${LIBS_VERSION}/${asset}"
    local stage="$TEMP_DIR/$platform"
    echo "==> ${platform}: downloading ${url}"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 -o "$TEMP_DIR/$asset" "$url"
    else
        wget -O "$TEMP_DIR/$asset" "$url"
    fi
    mkdir -p "$stage"
    tar -xjf "$TEMP_DIR/$asset" -C "$stage"
    [ -d "$stage/lib/$platform" ] || fail "Archive is missing lib/$platform/"
    [ -d "$stage/include" ] || fail "Archive is missing include/"
    local binary
    binary="$(find "$stage/lib/$platform" -type f -size +0c ! -name '.gitkeep' ! -name '*.md' -print -quit)"
    [ -n "$binary" ] || fail "Archive has no binaries for $platform"
    mkdir -p "$ADDON_DIR/libs/$LIB_NAME/lib/$platform" "$ADDON_DIR/libs/$LIB_NAME/include"
    cp -R "$stage/lib/$platform/." "$ADDON_DIR/libs/$LIB_NAME/lib/$platform/"
    cp -R "$stage/include/." "$ADDON_DIR/libs/$LIB_NAME/include/"
    echo "==> ${platform}: done"
}
if [ "$PLATFORM" = all ]; then
    for platform in $ALL_PLATFORMS; do download_one "$platform"; done
else
    download_one "$PLATFORM"
fi
echo "Libs ${LIBS_VERSION} installed for: ${PLATFORM}"
