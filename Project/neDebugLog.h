//
//  neDebugLog.h
//  jubeat plus
//
//  Optional runtime diagnostics. Emits os_log lines tagged "JBDBG" so they can be captured on
//  device with:  idevicesyslog | grep JBDBG
//
//  This code is NOT part of the original binary. It is compiled in only when the build defines
//  JBDBG (see the JBDBG CMake option, which is enable-able in any build configuration and is
//  turned on in CI). With JBDBG off the helpers below collapse to no-ops, so every translation
//  unit that only logs matches the reconstructed original exactly -- WITHOUT any `#if JBDBG` at
//  the call site:
//
//    * neDebugLog(...) becomes an empty inline, so a bare log call vanishes.
//    * NE_DBG_FIRST(n) becomes `(false)`, so an `if (NE_DBG_FIRST(n)) { ... }` block turns into
//      `if (false) { ... }` and is dead-code-eliminated; debug-only locals declared inside the
//      block stay "used" within it, so -Werror stays quiet. Put all diagnostic work inside that
//      block.
//    * NE_DBG(...) wraps debug statements that have real side effects we must NOT run in the
//      faithful build (for example glGetError(), which clears GL error state). It expands to the
//      statements when JBDBG is on and to nothing otherwise.
//

#pragma once

#ifndef JBDBG
#define JBDBG 0
#endif

#if JBDBG

// The C spellings, not <cstdarg>/<cstdio>: this header is included from pure Objective-C (.m)
// translation units, where the C++ headers do not exist.
#include <os/log.h>
#include <stdarg.h>
#include <stdio.h>

// printf-style wrapper over os_log (works in .c, .m, .cpp, and .mm translation units alike; os_log
// lines are what idevicesyslog captures).
static inline void neDebugLog(const char *fmt, ...) {
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    os_log(OS_LOG_DEFAULT, "JBDBG %{public}s", buf);
}

// A call counter helper: returns true for the first @c limit invocations at a given site, so a
// per-frame draw call can log a bounded burst instead of flooding the log at 60 fps. This is a
// statement expression rather than a lambda so that it compiles in the project's pure Objective-C
// (.m) translation units as well as the C++ ones.
#define NE_DBG_FIRST(limit)                                                                        \
    __extension__({                                                                                \
        static int _c = 0;                                                                         \
        _c < (limit) ? (++_c, 1) : 0;                                                              \
    })

// Wrap debug-only statements with real side effects. Internal `;` separates multiple statements;
// the macro supplies the trailing one.
#define NE_DBG(...)                                                                                \
    do {                                                                                           \
        __VA_ARGS__;                                                                               \
    } while (0)

#else

// No-op fallbacks: a bare, unguarded log call still compiles away to nothing, and
// NE_DBG_FIRST(n) collapses an `if (...) { ... }` diagnostic block to dead code that the optimiser
// drops.
static inline void neDebugLog(const char *fmt, ...) {
    (void)fmt;
}

// A plain 0 rather than `false`, which is a keyword only in C++ and would need <stdbool.h> in the
// pure Objective-C translation units.
#define NE_DBG_FIRST(limit) (0)
#define NE_DBG(...) ((void)0)

#endif

// The build's git SHA (set by CMake at configure time). Logged once at startup under JBDBG so a
// captured os_log identifies exactly which build produced it.
#ifndef JBDBG_BUILD_SHA
#define JBDBG_BUILD_SHA "unknown"
#endif

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
