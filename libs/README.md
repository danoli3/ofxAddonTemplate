# libs/

Library headers belong in `libs/<lib>/include/` and bundled source files in
`libs/<lib>/src/`. Project Generator, make and the native OF CMake helpers
compile these sources and add their header search paths automatically.

Platform-specific libraries use these folders:

    libs/<lib>/lib/osx/            macOS static libraries
    libs/<lib>/lib/macos/          Apple XCFrameworks
    libs/<lib>/lib/ios/            iOS
    libs/<lib>/lib/tvos/           tvOS
    libs/<lib>/lib/vs/             Windows Visual Studio (.lib)
    libs/<lib>/lib/msys2/          Windows MSYS2/MinGW
    libs/<lib>/lib/linux/64/       Linux x86_64
    libs/<lib>/lib/linux/armv6l/   Linux ARMv6
    libs/<lib>/lib/linux/armv7l/   Linux ARMv7
    libs/<lib>/lib/linux/aarch64/  Linux ARM64
    libs/<lib>/lib/android/<abi>/  Android ABI
    libs/<lib>/lib/emscripten/     Emscripten

Keep these platform names in sync with `addon_config.mk`. Empty directories
are represented by `.gitkeep`; the template contains no prebuilt binaries.
