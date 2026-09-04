# CMakeLists.txt - TEMPLATE for building an openFrameworks addon + example with CMake.
#
# Usage:
#   cmake -S . -B build -DOF_ROOT=/path/to/openFrameworks -DOF_TARGET=linux64
#   cmake --build build
#
# OF_TARGET must be one of the projectGenerator platform tokens, matching a
# folder under libs/<lib>/lib/ (see addon_config.mk sections):
#   osx | ios | tvos | vs | msys2 | linux64 | linuxarmv6l | linuxarmv7l |
#   linuxaarch64 | android | emscripten
#
cmake_minimum_required(VERSION 3.16)

# TODO: rename to your addon (must match addon_config.mk ADDON_NAME)
set(ADDON_NAME ofxMyAddon)
project(${ADDON_NAME} LANGUAGES C CXX)

set(OF_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../.." CACHE PATH "openFrameworks root")
set(OF_TARGET "linux64" CACHE STRING "OF platform token (see above)")

# Same language standards as apothecary (scripts/apothecary/apothecary/apothecary):
# C 17, C++ 23, honoring apothecary's C_STANDARD / CPP_STANDARD env overrides.
if("$ENV{C_STANDARD}" STREQUAL "")
    set(C_STANDARD 17)
else()
    set(C_STANDARD "$ENV{C_STANDARD}")
endif()
if("$ENV{CPP_STANDARD}" STREQUAL "")
    set(CPP_STANDARD 23)
else()
    set(CPP_STANDARD "$ENV{CPP_STANDARD}")
endif()
set(CMAKE_C_STANDARD ${C_STANDARD})
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD ${CPP_STANDARD})
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --- addon sources: mirrors what PG auto-discovers (src/ + libs/*/src|include).
# PG walks both trees recursively, so this recurses too: sources nested at any
# depth (e.g. libs/<lib>/src/vendor/sub/file.cpp) are picked up. Binaries under
# libs/*/lib/ are ignored by extension. To drop files per-platform, prune the
# lists (the equivalent of addon_config.mk ADDON_SOURCES_EXCLUDE), e.g.:
#   list(FILTER ADDON_SOURCES EXCLUDE REGEX ".*port/AndroidJNI.*")
file(GLOB_RECURSE ADDON_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cc"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cxx"
    "${CMAKE_CURRENT_SOURCE_DIR}/libs/*.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/libs/*.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/libs/*.cc"
    "${CMAKE_CURRENT_SOURCE_DIR}/libs/*.cxx")
file(GLOB_RECURSE ADDON_HEADERS CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/libs/*.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/libs/*.hpp")

add_library(${ADDON_NAME} STATIC ${ADDON_SOURCES} ${ADDON_HEADERS})
target_include_directories(${ADDON_NAME} PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}/src")

# Every lib folder becomes an include path, like the PG does.
file(GLOB LIB_INCLUDE_DIRS LIST_DIRECTORIES true "${CMAKE_CURRENT_SOURCE_DIR}/libs/*")
foreach(d IN LISTS LIB_INCLUDE_DIRS)
    if(IS_DIRECTORY "${d}")
        target_include_directories(${ADDON_NAME} PUBLIC "${d}/include" "${d}/src")
    endif()
endforeach()

# --- prebuilt binaries for this platform (download with scripts/download_libs.sh)
set(OF_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/libs")
file(GLOB PREBUILT_LIBS
    "${OF_LIB_DIR}/*/lib/${OF_TARGET}/*.a"
    "${OF_LIB_DIR}/*/lib/${OF_TARGET}/*.so"
    "${OF_LIB_DIR}/*/lib/${OF_TARGET}/*.dylib"
    "${OF_LIB_DIR}/*/lib/${OF_TARGET}/*.lib")
if(APPLE)
    # PG treats osx/macos as aliases; accept either folder.
    file(GLOB PREBUILT_LIBS_MACOS "${OF_LIB_DIR}/*/lib/macos/*")
    list(APPEND PREBUILT_LIBS ${PREBUILT_LIBS_MACOS})
endif()
if(PREBUILT_LIBS)
    target_link_libraries(${ADDON_NAME} PUBLIC ${PREBUILT_LIBS})
else()
    message(WARNING "No prebuilt libs for OF_TARGET=${OF_TARGET}; run scripts/download_libs.sh ${OF_TARGET}")
endif()

# --- OF core headers (compile against a tagged OF checkout, e.g. 0.12.1)
if(IS_DIRECTORY "${OF_ROOT}/libs/openFrameworks")
    target_include_directories(${ADDON_NAME} PUBLIC "${OF_ROOT}/libs/openFrameworks")
endif()
