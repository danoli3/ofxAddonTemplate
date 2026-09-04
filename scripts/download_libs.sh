#!/usr/bin/env bash
#
# download_libs.sh - download prebuilt addon binaries from GitHub releases.
#
# Usage:
#   scripts/download_libs.sh [platform] [-v <libs-version>] [-u <github-user/repo>]
#
#   platform: osx | macos | ios | tvos | vs | msys2 | linux64 |
#             linuxarmv6l | linuxarmv7l | linuxaarch64 |
#             android | emscripten | all
#             (default: auto-detected from the host machine)
#
# The platform names MUST match the folder names under libs/<lib>/lib/,
# because the projectGenerator links a binary only if its path contains
# the platform token (see ofAddon::getLibsRecursively).
#
# Release asset naming convention (created with scripts/build_libs.sh):
#   <addon-name>-libs-<platform>-<libs-version>.tar.bz2
# e.g. ofxMyAddon-libs-osx-1.0.0.tar.bz2
# Each archive unpacks to libs/<lib>/lib/<platform>/...
#
# On Windows run this from git-bash (ships with Git for Windows).
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$(dirname "$SCRIPT_DIR")"
ADDON_NAME="$(basename "$ADDON_DIR")"

# ---------------------------------------------------------------- TODO: edit
# GitHub repo hosting the releases, and the libs version to download.
# (Flag names mirror OF's scripts/dev/download_libs.sh: -v/--version.)
# Override from the command line with -u / -v, or via a scripts/libs_version.txt file.
GITHUB_REPO="yournamehere/${ADDON_NAME}"
LIBS_VERSION="1.0.0"
# Name of the lib folder under libs/ (must contain lib/<platform>/...).
LIB_NAME="necessaryLib"
# ----------------------------------------------------------------------------

if [ -f "$SCRIPT_DIR/libs_version.txt" ]; then
    LIBS_VERSION="$(tr -d ' \t\r\n' < "$SCRIPT_DIR/libs_version.txt")"
fi

PLATFORM=""
while [ $# -gt 0 ]; do
    case "$1" in
        -v|--version) LIBS_VERSION="$2"; shift 2 ;;
        -u|--repo)    GITHUB_REPO="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,/^$/p' "$0"; echo "Usage: $0 [platform] [-v <libs-version>] [-u <user/repo>]"
            exit 0 ;;
        *) PLATFORM="$1"; shift ;;
    esac
done

detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "$os" in
        Darwin) echo "osx" ;;
        MINGW*|MSYS*|CYGWIN*) echo "msys2" ;;
        Linux)
            case "$arch" in
                x86_64) echo "linux64" ;;
                armv6l) echo "linuxarmv6l" ;;
                armv7l) echo "linuxarmv7l" ;;
                aarch64) echo "linuxaarch64" ;;
                *) echo "linux64" ;;
            esac ;;
        *) echo "linux64" ;;
    esac
}

if [ -z "$PLATFORM" ]; then
    PLATFORM="$(detect_platform)"
fi

ALL_PLATFORMS="osx ios tvos vs msys2 linux64 linuxarmv6l linuxarmv7l linuxaarch64 android emscripten"
if [ "$PLATFORM" = "macos" ]; then
    PLATFORM="osx" # PG treats them as aliases; releases use "osx"
fi

download_one() {
    local platform="$1"
    local asset="${ADDON_NAME}-libs-${platform}-${LIBS_VERSION}.tar.bz2"
    local url="https://github.com/${GITHUB_REPO}/releases/download/${LIBS_VERSION}/${asset}"
    echo "==> ${platform}: downloading ${url}"
    mkdir -p "$ADDON_DIR/libs/$LIB_NAME"
    if command -v curl >/dev/null 2>&1; then
        curl -fL -o "/tmp/${asset}" "$url"
    else
        wget -O "/tmp/${asset}" "$url"
    fi
    tar -xjf "/tmp/${asset}" -C "$ADDON_DIR/libs/$LIB_NAME"
    rm -f "/tmp/${asset}"
    if [ ! -d "$ADDON_DIR/libs/$LIB_NAME/lib/$platform" ] && [ "$platform" != "android" ]; then
        echo "WARNING: archive did not contain libs/$LIB_NAME/lib/$platform/" >&2
    fi
    echo "==> ${platform}: done"
}

if [ "$PLATFORM" = "all" ]; then
    for p in $ALL_PLATFORMS; do
        download_one "$p"
    done
else
    download_one "$PLATFORM"
fi

echo "Libs ${LIBS_VERSION} installed for: ${PLATFORM}"
