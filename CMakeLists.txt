# CMakeLists.txt — jubeat plus reconstruction  (root)
#
# The original 3.9.11 binary (Jubeat) is arm64, so the default slice set is simply
# arm64; add arm64e with -DIOS_ARCHS="arm64 arm64e" if your toolchain has arm64e
# app codegen. This file builds a NATIVE iOS .app. Configure with `-G Xcode` plus
# the leetal/ios-cmake toolchain to build the .app target from the per-directory
# source tree:
#
#   cmake -G Xcode -DCMAKE_TOOLCHAIN_FILE=/path/to/ios.toolchain.cmake -DPLATFORM=OS64 ..
#
# Theos is supported too, but NOT through CMake: it has its own hand-maintained, fixed
# Theos application Makefile under ./theos/ (build with `make -C theos`). See theos/Makefile.
#
# Every knob below is a CACHE entry, so ALL of them (bundle id, name, version, archs,
# deployment target, tool paths) are overridable on the command line with -D<name>=..

cmake_minimum_required(VERSION 3.14)

# Documentation switches sit before project() because a docs-only configure must
# not probe for the Objective-C toolchain: the GitHub Pages runner is Linux and
# has no OBJC/OBJCXX compilers, so that mode declares no languages at all.
option(BUILD_DOCS "Build documentation." OFF)
option(BUILD_DOCS_ONLY "Build documentation only." OFF)

if(BUILD_DOCS_ONLY)
    project(JubeatPlus VERSION 3.9.11 LANGUAGES NONE)
else()
    project(JubeatPlus
            VERSION 3.9.11
            LANGUAGES C CXX OBJC OBJCXX)
endif()

# ---------------------------------------------------------------------------
# Documentation (Doxygen). The ghidraAddress alias implements this project's
# custom @ghidraAddress tag, which ties a reconstructed routine to its function
# in the original binary (address relative to the program's image base).
# DOXYGEN_VERBATIM_VARS stops CMake re-quoting the alias, so the embedded
# Doxygen-side quoting reaches the Doxyfile intact.
# ---------------------------------------------------------------------------
if(BUILD_DOCS OR BUILD_DOCS_ONLY)
    set(DOXYGEN_USE_MDFILE_AS_MAINPAGE "${CMAKE_SOURCE_DIR}/README.md")
    set(DOXYGEN_GENERATE_HTML YES)
    set(DOXYGEN_VERBATIM_VARS DOXYGEN_ALIASES)
    set(DOXYGEN_ALIASES [[ghidraAddress="\par Ghidra address:^^"]])
    find_package(Doxygen REQUIRED)
    doxygen_add_docs(docs README.md Project ALL)
endif()
if(BUILD_DOCS_ONLY)
    return()
endif()

# ---------------------------------------------------------------------------
# User-facing options (all overridable via -D...)
# ---------------------------------------------------------------------------
set(IOS_ARCHS "arm64" CACHE STRING "Space-separated architecture slices")
# The shipped binary's Info.plist declares MinimumOSVersion 11.0.
set(IOS_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum iOS version")
if(DEFINED DEPLOYMENT_TARGET)                 # leetal/ios-cmake spelling
    set(IOS_DEPLOYMENT_TARGET "${DEPLOYMENT_TARGET}")
endif()

set(XCODE_PATH ""            CACHE PATH "Path to Xcode developer dir (blank = xcode-select)")

# Defaults mirror the shipped Info.plist: bundle id jp.konami.jubeatplus, version 3.9.11.
set(APP_BUNDLE_ID    "jp.konami.jubeatplus" CACHE STRING "CFBundleIdentifier")
set(APP_DISPLAY_NAME "jubeat plus"          CACHE STRING "CFBundleDisplayName")
set(APP_VERSION      "3.9.11"               CACHE STRING "CFBundleShortVersionString")
set(APP_BUILD        "3.9.11"               CACHE STRING "CFBundleVersion")
set(RESOURCES_DIR    "" CACHE PATH "Directory of the ORIGINAL extracted .app whose resources "
                                   "(images, sounds, data files, fonts, ...) are copied "
                                   "verbatim into the built bundle. Leave empty to build code only.")

# ENABLE_PATCHES compiles in preservation patches guarded by #ifdef ENABLE_PATCHES
# (patched code under the #ifdef, the original under #else). It is NOT part of the
# original binary, so it defaults OFF and the shipped build matches the binary. It
# is a plain cache option, so it can be enabled in ANY build configuration with
# -DENABLE_PATCHES=ON.
option(ENABLE_PATCHES "Compile in preservation patches (skip dead service flows)" OFF)

# ---------------------------------------------------------------------------
# Toolchain discovery (informational)
# ---------------------------------------------------------------------------
if(NOT XCODE_PATH)
    find_program(XCODE_SELECT xcode-select)
    if(XCODE_SELECT)
        execute_process(COMMAND ${XCODE_SELECT} -p
                        OUTPUT_VARIABLE _xcp OUTPUT_STRIP_TRAILING_WHITESPACE
                        ERROR_QUIET RESULT_VARIABLE _xcr)
        if(_xcr EQUAL 0 AND _xcp)
            set(XCODE_PATH "${_xcp}")
        endif()
    endif()
endif()
if(XCODE_PATH AND EXISTS "${XCODE_PATH}")
    message(STATUS "JubeatPlus: found Xcode/developer dir at ${XCODE_PATH}")
endif()
message(STATUS "JubeatPlus: archs='${IOS_ARCHS}' iOS>=${IOS_DEPLOYMENT_TARGET}")

# Frameworks actually #import-ed across the sources.
set(SYS_FRAMEWORKS
    UIKit Foundation CoreFoundation CoreGraphics QuartzCore
    OpenGLES AudioToolbox AVFoundation CoreMedia OpenAL
    CoreData StoreKit Social
    Security SafariServices
    AdSupport CoreMotion
    GameKit CoreLocation MapKit MultipeerConnectivity)

# =========================================================================
# NATIVE / Xcode — real .app target, fed by per-directory CMakeLists.
# =========================================================================
set(INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/Info.plist")
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in" "${INFO_PLIST}" @ONLY)

# Single app target, fed by per-directory CMakeLists (each appends its own translation
# units via target_sources(jubeat ...) and puts its dir on the include path).
#
# NOTE: per-directory static libraries are deliberately NOT used. Unlike C, Objective-C
# classes referenced only by name/selector (NSStringFromClass, imageNamed:, string-keyed
# lookups) carry no link-time reference, so the linker strips whole classes/categories out
# of a static archive — you have to paper over it with -force_load/-ObjC. That is not the
# clean "C static lib" model, so we keep one translation-unit set in a single target.
add_executable(jubeat MACOSX_BUNDLE)
target_include_directories(jubeat PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/Project")

add_subdirectory(Project)

# Compiler options as real -flags (not XCODE_ATTRIBUTE build settings) so they
# apply under every generator and can be overridden per source file. Language
# standards are per-language (AppleClang 15 / LLVM 16 spells C23 / C++23 gnu2x /
# gnu++2b); ARC and its exception cleanup are Objective-C only; stack variables
# are zero-initialised (matching the binary's memset-zeroed work areas; the flag
# is non-experimental as of clang 16).
target_compile_options(jubeat PRIVATE
    $<$<COMPILE_LANGUAGE:C,OBJC>:-std=gnu2x>
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-std=gnu++2b>
    -include "${CMAKE_CURRENT_SOURCE_DIR}/Project/nullptr_compat.h"
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-stdlib=libc++>
    # Keep u8"" literals as char[] (C-era UTF-8 strings used as const char*);
    # C++20 otherwise makes them char8_t[].
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-fno-char8_t>
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-fobjc-arc>
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-fobjc-arc-exceptions>
    # libc++ hardening (Xcode's CLANG_CXX_STANDARD_LIBRARY_HARDENING "fast").
    # The CI toolchain is AppleClang 15 / LLVM 16, whose libc++ predates the
    # _LIBCPP_HARDENING_MODE macro (LLVM 18+); the effective knob there is
    # _LIBCPP_ENABLE_ASSERTIONS, which newer libc++ still honours (mapped to the
    # hardened mode). ABI-neutral, low overhead: bad indices / iterators trap
    # instead of corrupting memory.
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-D_LIBCPP_ENABLE_ASSERTIONS=1>
    -ftrivial-auto-var-init=zero)

# Warnings: most of Xcode's recommended GCC_WARN_* / CLANG_WARN_* set as real -W
# flags. Every warning is an error (-Werror), so the build fails on any of them,
# with two exceptions kept as printed warnings: -Wdeprecated-declarations (the
# reconstruction faithfully uses APIs Apple has since deprecated) and
# -Wunused-parameter (the de-inlined helpers and delegate methods keep the
# binary's full parameter lists even where a body ignores an argument). The
# noisy conversion / cast / pedantic families are deliberately left off: this is
# a faithful binary reconstruction with intentional narrowing, pointer-in-int and
# reinterpret casts.
target_compile_options(jubeat PRIVATE
    -Werror
    -Wno-error=deprecated-declarations
    -Wno-error=unused-parameter
    -Wall
    -Wextra
    -Wshadow
    -Wcomma
    -Wnewline-eof
    -Wpointer-arith
    -Wimplicit-fallthrough
    -Wunreachable-code
    -Wconditional-uninitialized
    -Winfinite-recursion
    # C++ / Objective-C++
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-Woverloaded-virtual>
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-Wnon-virtual-dtor>
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-Wdelete-non-abstract-non-virtual-dtor>
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-Wrange-loop-analysis>
    $<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-Wextra-semi>
    # Objective-C / Objective-C++
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-Wundeclared-selector>
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-Wblock-capture-autoreleasing>
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-Wobjc-literal-conversion>
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-Wduplicate-method-match>
    $<$<COMPILE_LANGUAGE:OBJC,OBJCXX>:-Wimplicit-retain-self>)

# The reconstruction faithfully uses the OpenGL ES 1.1 API, which Apple
# deprecated wholesale on iOS 12 with no in-place replacement (Metal is a
# separate stack). Silence the blanket ES deprecation warnings rather than
# rewrite the renderer.
target_compile_definitions(jubeat PRIVATE GLES_SILENCE_DEPRECATION)

# When ENABLE_PATCHES is enabled, define it for every translation unit; the
# generator expression is config-agnostic, so it applies in Debug, Release, and
# any other configuration alike.
target_compile_definitions(jubeat PRIVATE $<$<BOOL:${ENABLE_PATCHES}>:ENABLE_PATCHES=1>)

set_target_properties(jubeat PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${INFO_PLIST}"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${APP_BUNDLE_ID}"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "${IOS_DEPLOYMENT_TARGET}"
    XCODE_ATTRIBUTE_ARCHS "${IOS_ARCHS}"
    XCODE_ATTRIBUTE_VALID_ARCHS "${IOS_ARCHS}"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH "NO"
    XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
    # This build is never submitted to the App Store.
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_SKIP_APP_STORE_DEPLOYMENT "YES"
    # Turn the static analyzer's checkers on.
    XCODE_ATTRIBUTE_CLANG_ANALYZER_LOCALIZABILITY_EMPTY_CONTEXT "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_DIVIDE_BY_ZERO "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_DEADCODE_DEADSTORES "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_NONNULL "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_NULL_DEREFERENCE "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_ATSYNC "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_COLLECTIONS "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_GENERICS "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_INCOMP_METHOD_TYPES "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_NSCFERROR "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_SELF_INIT "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_OBJC_UNUSED_IVARS "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_SECURITY_BUFFER_OVERFLOW_EXPERIMENTAL "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_SECURITY_FLOATLOOPCOUNTER "YES"
    XCODE_ATTRIBUTE_CLANG_ANALYZER_USE_AFTER_MOVE "YES"
    # Run the static analyzer in its deep (cross-function) mode.
    XCODE_ATTRIBUTE_CLANG_STATIC_ANALYZER_MODE "Deep"
    XCODE_ATTRIBUTE_CLANG_STATIC_ANALYZER_MODE_ON_ANALYZE_ACTION "Deep"
    # Extra clang-tidy bugprone checks.
    XCODE_ATTRIBUTE_CLANG_TIDY_BUGPRONE_ASSERT_SIDE_EFFECT "YES"
    XCODE_ATTRIBUTE_CLANG_TIDY_BUGPRONE_INFINITE_LOOP "YES"
    XCODE_ATTRIBUTE_CLANG_TIDY_BUGPRONE_MOVE_FORWARDING_REFERENCE "YES"
    OUTPUT_NAME "Jubeat")

foreach(_fw ${SYS_FRAMEWORKS})
    find_library(FW_${_fw} ${_fw})
    if(FW_${_fw})
        target_link_libraries(jubeat PRIVATE ${FW_${_fw}})
    else()
        target_link_libraries(jubeat PRIVATE "-framework ${_fw}")
    endif()
endforeach()
target_link_libraries(jubeat PRIVATE z)   # CommonCrypto is in libSystem; zlib for minizip

if(RESOURCES_DIR AND EXISTS "${RESOURCES_DIR}")
    file(GLOB RES_ENTRIES "${RESOURCES_DIR}/*")
    foreach(_res ${RES_ENTRIES})
        get_filename_component(_name "${_res}" NAME)
        if(NOT _name MATCHES "^(Jubeat|_CodeSignature|CodeResources|embedded\\.mobileprovision|Info\\.plist|PkgInfo)$")
            target_sources(jubeat PRIVATE "${_res}")
            set_source_files_properties("${_res}" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
        endif()
    endforeach()
    message(STATUS "JubeatPlus: bundling resources from ${RESOURCES_DIR}")
else()
    message(WARNING "JubeatPlus: RESOURCES_DIR not set — building CODE ONLY (links, but no assets).")
endif()

# kate: hl CMake; replace-tabs on; indent-width 4; tab-width 4;
