# libs/

Prebuilt binaries live here, one folder per openFrameworks platform token:

    libs/<lib>/lib/osx/            macOS static libraries
    libs/<lib>/lib/macos/          Apple XCFrameworks (one or multiple platforms)
    libs/<lib>/lib/ios/            iOS
    libs/<lib>/lib/tvos/           tvOS
    libs/<lib>/lib/vs/             Windows Visual Studio (.lib)
    libs/<lib>/lib/msys2/          Windows MSYS2/MinGW
    libs/<lib>/lib/linux/64/        Linux x86_64
    libs/<lib>/lib/linux/armv6l/    Linux ARMv6 (Raspberry Pi 1/Zero)
    libs/<lib>/lib/linux/armv7l/    Linux ARMv7 (Raspberry Pi 2/3)
    libs/<lib>/lib/linux/aarch64/   Linux ARM64
    libs/<lib>/lib/android/<abi>/  armeabi-v7a, arm64-v8a, x86, x86_64
    libs/<lib>/lib/emscripten/     Emscripten (WebAssembly)

The names are load-bearing: the projectGenerator links a binary only if its
path contains the platform token, and `scripts/download_libs.sh` resolves the
same names to GitHub release assets.

Binaries are NOT committed (see `.gitignore`). Fetch them with:

    ./scripts/download_libs.sh            # auto-detect host platform
    ./scripts/download_libs.sh linux/64    # or: all, osx, ios, vs, ...

Linux release archives use names such as
`ofxAddonTemplate-libs-linux-64-1.0.0.tar.bz2`, containing `lib/linux/64/`.
The scripts accept the old `linux64`, `linuxarmv6l`, `linuxarmv7l` and
`linuxaarch64` arguments as aliases, but always package and install the nested
`linux/<arch>` paths. Auto-detection and `all` use the nested names too.

Sources under `libs/<lib>/src/` are compiled automatically. Headers under
`include/` are added to the include paths by Project Generator, make and the
native OF CMake helpers.

For binary releases, edit `scripts/libs_common.sh` (repository and library
folder) and `scripts/libs_version.txt` (release tag). Build your library into
`lib/<platform>/` first, then run `scripts/build_libs.sh <platform>`. The script
rejects empty skeleton directories. Upload its archive to the matching GitHub
release, or use `--upload -u owner/repo` for an existing release.

If the binary contains the same code as `src/`, exclude those sources to avoid
duplicate definitions. For example, in the appropriate `addon_config.mk` section:

    ADDON_SOURCES_EXCLUDE += libs/necessaryLib/src/%

The template defaults to bundled sources; no download or release is required.

## Apple XCFrameworks

`scripts/build_xcframework.sh` combines **already built static libraries**. It
uses `lipo` only to merge architectures for the same platform and variant, then
uses `xcodebuild -create-xcframework` to collect the platforms. It requires
Xcode and Python 3 on macOS; build the actual library separately for each SDK.
Device and simulator binaries remain separate, even when both use arm64.

For a universal macOS XCFramework:

```sh
./scripts/build_xcframework.sh --platform macos \
  --slice macos/arm64=build/mac-arm64/libnecessaryLib.a \
  --slice macos/x86_64=build/mac-x86_64/libnecessaryLib.a
```

For iOS device plus a universal simulator:

```sh
./scripts/build_xcframework.sh --platform ios \
  --slice ios/arm64=build/ios-device/libnecessaryLib.a \
  --slice ios-simulator/arm64=build/ios-sim-arm64/libnecessaryLib.a \
  --slice ios-simulator/x86_64=build/ios-sim-x86_64/libnecessaryLib.a
```

For **one XCFramework containing all supplied Apple platforms**, pass all five
slices above in the same invocation with `--platform all` (the default). Add
`tvos`, `tvos-simulator`, `xros`, `xros-simulator`, `watchos`,
`watchos-simulator` or `catalyst` slices in the same `platform/arch=path` form
for further targets. Only supplied slices are included; missing SDK builds are
not compiled or invented. Duplicate slices, architecture mismatches and
incorrect platform/variant labels are rejected.

The default output is `libs/necessaryLib/lib/macos/necessaryLib.xcframework`
for `macos` or `all`, and `lib/ios/necessaryLib.xcframework` for `ios` (similarly
for tvOS, visionOS and watchOS). `--name`, `--headers` and `--output` override
the defaults. Existing output requires `--force`; a failed merge leaves the
existing XCFramework in place.

Publish and install the combined Apple package with:

```sh
./scripts/build_libs.sh macos -v 1.0.0
./scripts/download_libs.sh macos -v 1.0.0 -u owner/repo
```

`macos` now denotes the XCFramework folder and release asset
`<addon>-libs-macos-<version>.tar.bz2`; use `osx` for the separate desktop
static-library package. A combined `macos` package contains all the Apple
slices in its XCFramework and can be installed for an iOS/tvOS consumer too.

For targets that do not automatically search `lib/macos`, explicitly select
that shared XCFramework in each relevant Apple section of `addon_config.mk`:

```make
osx:
    ADDON_LIBS = libs/necessaryLib/lib/macos/necessaryLib.xcframework
    ADDON_SOURCES_EXCLUDE += libs/necessaryLib/src/%
ios:
    ADDON_LIBS = libs/necessaryLib/lib/macos/necessaryLib.xcframework
    ADDON_SOURCES_EXCLUDE += libs/necessaryLib/src/%
tvos:
    ADDON_LIBS = libs/necessaryLib/lib/macos/necessaryLib.xcframework
    ADDON_SOURCES_EXCLUDE += libs/necessaryLib/src/%
```

Add equivalent `macos:`, `xros:` or `watchos:` sections as needed for your
consumer's build system. Supported build systems select the XCFramework slice
for the target SDK. Source-only projects can leave these settings unset.
