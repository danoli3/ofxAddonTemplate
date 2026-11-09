#!/usr/bin/env bash
# Shared release settings. Edit these when creating your addon.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$(dirname "$SCRIPT_DIR")"
ADDON_NAME="$(basename "$ADDON_DIR")"
GITHUB_REPO="yournamehere/${ADDON_NAME}"
LIB_NAME="necessaryLib"
LIBS_VERSION="$(tr -d ' \t\r\n' < "$SCRIPT_DIR/libs_version.txt")"
ALL_PLATFORMS="osx ios tvos vs msys2 linux64 linuxarmv6l linuxarmv7l linuxaarch64 android emscripten"

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
                x86_64) echo linux64 ;;
                armv6l) echo linuxarmv6l ;;
                armv7l) echo linuxarmv7l ;;
                aarch64|arm64) echo linuxaarch64 ;;
                *) fail "Unsupported Linux architecture; specify a platform" ;;
            esac ;;
        *) fail "Unsupported host; specify a platform" ;;
    esac
}
validate_platform() {
    [ -n "$PLATFORM" ] || PLATFORM="$(detect_platform)"
    [ "$PLATFORM" != macos ] || PLATFORM=osx
    case " $ALL_PLATFORMS " in
        *" $PLATFORM "*) ;;
        *) [ "$PLATFORM" = all ] && [ "${ALLOW_ALL:-0}" = 1 ] || fail "Unsupported platform: $PLATFORM" ;;
    esac
    [[ "$LIBS_VERSION" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "Invalid libs version: $LIBS_VERSION"
}
