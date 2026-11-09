#!/usr/bin/env bash
# Merge prebuilt Apple static-library slices into an XCFramework.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/libs_common.sh"

usage() {
    cat <<'HELP'
Usage: scripts/build_xcframework.sh [options] --slice platform/arch=library.a ...

  --platform macos|ios|tvos|xros|watchos|catalyst|all   default: all
  --slice PLATFORM/ARCH=PATH   repeat for each thin static library
  --headers DIR               default: libs/<LIB_NAME>/include
  --name NAME                 default: LIB_NAME from libs_common.sh
  --output DIR.xcframework    override the output path
  --force                     replace an existing XCFramework

Slice platforms: macos, ios, ios-simulator, tvos, tvos-simulator,
xros, xros-simulator, watchos, watchos-simulator, catalyst.
Example: --slice macos/arm64=build/mac-arm64/libFoo.a
         --slice macos/x86_64=build/mac-x86_64/libFoo.a
         --slice ios/arm64=build/ios/libFoo.a
         --slice ios-simulator/arm64=build/sim-arm64/libFoo.a
         --slice ios-simulator/x86_64=build/sim-x86_64/libFoo.a

Architectures are merged only within the same platform/variant. The default
'all' puts every supplied platform into libs/<LIB_NAME>/lib/macos/<NAME>.xcframework.
An ios-only build goes in lib/ios/, tvos in lib/tvos/, etc. Requires Xcode and Python 3.
HELP
}
TARGET=all
NAME="$LIB_NAME"
HEADERS="$ADDON_DIR/libs/$LIB_NAME/include"
OUTPUT=""
FORCE=0
SLICE_KEYS=()
SLICE_FILES=()
while [ $# -gt 0 ]; do
    case "$1" in
        --platform) require_value "$@"; TARGET="$2"; shift 2 ;;
        --headers) require_value "$@"; HEADERS="$2"; shift 2 ;;
        --name) require_value "$@"; NAME="$2"; shift 2 ;;
        --output) require_value "$@"; OUTPUT="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --slice)
            require_value "$@"
            [[ "$2" == *=* ]] || fail "Slice must be platform/arch=path: $2"
            SLICE_KEYS+=("${2%%=*}")
            SLICE_FILES+=("${2#*=}")
            shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown argument: $1" ;;
    esac
done
case "$TARGET" in macos|ios|tvos|xros|watchos|catalyst|all) ;; *) fail "Unsupported Apple platform: $TARGET" ;; esac
[[ "$NAME" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]] || fail "Invalid library name: $NAME"
[ "${#SLICE_KEYS[@]}" -gt 0 ] || fail "Supply at least one --slice (see --help)"
[ -d "$HEADERS" ] || fail "Headers directory not found: $HEADERS"
HEADERS="$(cd "$HEADERS" && pwd)"
for tool in xcrun xcodebuild python3; do
    command -v "$tool" >/dev/null 2>&1 || fail "Required tool not found: $tool"
done

# Validate all inputs before creating an output, including unselected families.
for i in "${!SLICE_KEYS[@]}"; do
    key="${SLICE_KEYS[$i]}"
    group="${key%/*}"
    arch="${key##*/}"
    case "$group" in
        macos|ios|ios-simulator|tvos|tvos-simulator|xros|xros-simulator|watchos|watchos-simulator|catalyst) ;;
        *) fail "Unsupported slice platform: $key" ;;
    esac
    case "$arch" in arm64|arm64e|arm64_32|armv7k|x86_64) ;; *) fail "Unsupported slice architecture: $key" ;; esac
    [ -f "${SLICE_FILES[$i]}" ] || fail "Library not found: ${SLICE_FILES[$i]}"
    for ((j=0; j<i; j++)); do
        [ "${SLICE_KEYS[$j]}" != "$key" ] || fail "Duplicate slice: $key"
    done
    actual="$(xcrun lipo -archs "${SLICE_FILES[$i]}")"
    [ "$actual" = "$arch" ] || fail "$key must contain only $arch; found: $actual"
done

if [ -z "$OUTPUT" ]; then
    folder="$TARGET"
    [ "$folder" != all ] || folder=macos
    [ "$folder" != catalyst ] || folder=ios
    OUTPUT="$ADDON_DIR/libs/$LIB_NAME/lib/$folder/$NAME.xcframework"
fi
[[ "$OUTPUT" == *.xcframework ]] || fail "Output must end in .xcframework"
[ ! -e "$OUTPUT" ] || [ "$FORCE" = 1 ] || fail "Output exists (use --force): $OUTPUT"
mkdir -p "$(dirname "$OUTPUT")"
OUTPUT="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"
TEMP_DIR="$(mktemp -d "$(dirname "$OUTPUT")/.xcframework-build.XXXXXX")"
cleanup() {
    if [ -d "$TEMP_DIR/previous.xcframework" ] && [ ! -e "$OUTPUT" ]; then
        mv "$TEMP_DIR/previous.xcframework" "$OUTPUT"
    fi
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

XC_ARGS=()
SELECTED_GROUPS=()
for group in macos ios ios-simulator tvos tvos-simulator xros xros-simulator watchos watchos-simulator catalyst; do
    family="${group%-simulator}"
    [ "$TARGET" = all ] || [ "$TARGET" = "$family" ] || continue
    FILES=()
    for i in "${!SLICE_KEYS[@]}"; do
        if [ "${SLICE_KEYS[$i]%/*}" = "$group" ]; then FILES+=("${SLICE_FILES[$i]}"); fi
    done
    [ "${#FILES[@]}" -gt 0 ] || continue
    mkdir -p "$TEMP_DIR/$group"
    library="$TEMP_DIR/$group/lib$NAME.a"
    if [ "${#FILES[@]}" -eq 1 ]; then
        cp "${FILES[0]}" "$library"
    else
        xcrun lipo -create "${FILES[@]}" -output "$library"
    fi
    echo "==> $group: $(xcrun lipo -archs "$library")"
    XC_ARGS+=(-library "$library" -headers "$HEADERS")
    SELECTED_GROUPS+=("$group")
done
[ "${#SELECTED_GROUPS[@]}" -gt 0 ] || fail "No slices supplied for --platform $TARGET"
PRODUCT="$TEMP_DIR/$NAME.xcframework"
xcodebuild -create-xcframework "${XC_ARGS[@]}" -output "$PRODUCT"

# Check actual Mach-O platform metadata, so a mislabeled device/simulator slice
# cannot silently produce an XCFramework for a different target.
python3 - "$PRODUCT/Info.plist" "${SELECTED_GROUPS[@]}" <<'PY'
import plistlib
import sys
with open(sys.argv[1], 'rb') as stream:
    libraries = plistlib.load(stream)['AvailableLibraries']
def platform(group):
    if group == 'catalyst':
        return ('ios', 'maccatalyst')
    if group.endswith('-simulator'):
        return (group[:-10], 'simulator')
    return (group, '')
expected = {platform(group) for group in sys.argv[2:]}
actual = {(lib['SupportedPlatform'], lib.get('SupportedPlatformVariant', '')) for lib in libraries}
if expected != actual or len(libraries) != len(expected):
    sys.exit(f'ERROR: Slice platform metadata does not match --slice labels: expected {sorted(expected)}, got {sorted(actual)}')
PY
if [ -e "$OUTPUT" ]; then mv "$OUTPUT" "$TEMP_DIR/previous.xcframework"; fi
mv "$PRODUCT" "$OUTPUT"
echo "==> wrote $OUTPUT"
