# libs/

Prebuilt binaries live here, one folder per openFrameworks platform token:

    libs/<lib>/lib/osx/            macOS (also matches the `macos` alias)
    libs/<lib>/lib/ios/            iOS
    libs/<lib>/lib/tvos/           tvOS
    libs/<lib>/lib/vs/             Windows Visual Studio (.lib)
    libs/<lib>/lib/msys2/          Windows MSYS2/MinGW
    libs/<lib>/lib/linux64/        Linux x86_64
    libs/<lib>/lib/linuxarmv6l/    Linux ARMv6 (Raspberry Pi 1/Zero)
    libs/<lib>/lib/linuxarmv7l/    Linux ARMv7 (Raspberry Pi 2/3)
    libs/<lib>/lib/linuxaarch64/   Linux ARM64
    libs/<lib>/lib/android/<abi>/  armeabi-v7a, arm64-v8a, x86, x86_64
    libs/<lib>/lib/emscripten/     Emscripten (WebAssembly)

The names are load-bearing: the projectGenerator links a binary only if its
path contains the platform token, and `scripts/download_libs.sh` resolves the
same names to GitHub release assets.

Binaries are NOT committed (see `.gitignore`). Fetch them with:

    ./scripts/download_libs.sh            # auto-detect host platform
    ./scripts/download_libs.sh linux64    # or: all, osx, ios, vs, ...

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
