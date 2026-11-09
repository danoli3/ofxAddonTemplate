#!/usr/bin/env bash
# Shared release settings. Edit these when creating your addon.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$(dirname "$SCRIPT_DIR")"
ADDON_NAME="$(basename "$ADDON_DIR")"
GITHUB_REPO="yournamehere/${ADDON_NAME}"
LIB_NAME="necessaryLib"
LIBS_VERSION="$(tr -d ' \t\r\n' < "$SCRIPT_DIR/libs_version.txt")"
ALL_PLATFORMS="osx macos ios tvos vs msys2 linux/64 linux/armv6l linux/armv7l linux/aarch64 android emscripten"

fail() { echo "ERROR: $*" >&2; exit 1; }
require_value() {
    [ "$#" -ge 2 ] && [ -n "$2" ] && [[ "$2" != -* ]] || fail "$1 requires a value"
}
detect_platform() {
    case "$(uname -s)" in
        Darwin) echo osx ;;
        MINGW*|MSYS*|CYGWIN*) echo msys2 ;;
        Linux)
            case "$(uname -m)" in
                x86_64) echo linux/64 ;;
                armv6l) echo linux/armv6l ;;
                armv7l) echo linux/armv7l ;;
                aarch64|arm64) echo linux/aarch64 ;;
                *) fail "Unsupported Linux architecture; specify a platform" ;;
            esac ;;
        *) fail "Unsupported host; specify a platform" ;;
    esac
}
validate_platform() {
    [ -n "$PLATFORM" ] || PLATFORM="$(detect_platform)"
    case "$PLATFORM" in
        linux64) PLATFORM=linux/64 ;;
        linuxarmv6l) PLATFORM=linux/armv6l ;;
        linuxarmv7l) PLATFORM=linux/armv7l ;;
        linuxaarch64) PLATFORM=linux/aarch64 ;;
    esac
    case " $ALL_PLATFORMS " in
        *" $PLATFORM "*) ;;
        *) [ "$PLATFORM" = all ] && [ "${ALLOW_ALL:-0}" = 1 ] || fail "Unsupported platform: $PLATFORM" ;;
    esac
    [[ "$LIBS_VERSION" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "Invalid libs version: $LIBS_VERSION"
}

# GitHub asset filenames cannot contain the slash used by library folders.
release_asset_name() {
    local platform="$1"
    printf '%s-libs-%s-%s.tar.bz2' "$ADDON_NAME" "${platform//\//-}" "$LIBS_VERSION"
}
