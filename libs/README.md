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

Sources under `libs/<lib>/src/` and headers under `libs/<lib>/include/` are
compiled automatically by the projectGenerator and the CMakeLists template -
no `addon_config.mk` entries needed.
