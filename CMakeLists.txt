# Build the addon and its examples using openFrameworks' CMake support.
# Requires an OF checkout containing project/CMake/openFrameworks.cmake.
#   cmake -S . -B build -DOF_ROOT=/path/to/openFrameworks
#   cmake --build build --parallel
cmake_minimum_required(VERSION 3.22)
project(ofxAddonTemplate LANGUAGES C CXX)

set(OF_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../.." CACHE PATH "openFrameworks root")
set(OF_CMAKE "${OF_ROOT}/libs/openFrameworksCompiled/project/CMake/openFrameworks.cmake")
if(NOT EXISTS "${OF_CMAKE}")
    message(FATAL_ERROR "OF_ROOT must point to an openFrameworks checkout with native CMake support (current master).")
endif()
include("${OF_CMAKE}")

# Sources, includes, dependencies and platform libraries come from the same
# addon_config.mk and folder layout used by Project Generator and make.
of_use_core()
add_library(${PROJECT_NAME} STATIC)
of_target_addons(${PROJECT_NAME} "${CMAKE_CURRENT_SOURCE_DIR}")
target_include_directories(${PROJECT_NAME} PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_link_libraries(${PROJECT_NAME} PUBLIC openFrameworks::openFrameworks)

option(ADDON_BUILD_EXAMPLES "Build the addon examples" ON)
if(ADDON_BUILD_EXAMPLES)
    file(GLOB EXAMPLES LIST_DIRECTORIES true "${CMAKE_CURRENT_SOURCE_DIR}/example_*")
    foreach(EXAMPLE IN LISTS EXAMPLES)
        if(IS_DIRECTORY "${EXAMPLE}/src")
            get_filename_component(EXAMPLE_NAME "${EXAMPLE}" NAME)
            of_add_app(${EXAMPLE_NAME} PROJECT_DIR "${EXAMPLE}")
        endif()
    endforeach()
endif()
