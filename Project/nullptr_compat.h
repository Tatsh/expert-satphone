/**
 * @file
 * @brief Fallback definition of @c nullptr for pre-C23 C compilers.
 *
 * The reconstructed sources use @c nullptr for every C and C++ null pointer. @c nullptr is a
 * keyword in C++11 and later and in C23, so no definition is needed there. This header supplies a
 * fallback only when the translation unit is compiled as C older than C23, where @c nullptr is not
 * yet a keyword.
 *
 * This is not reconstructed from the binary; it is a portability shim for this source tree. Wire it
 * in by passing @c -include @c nullptr_compat.h to the compiler (from @c theos/Makefile and the
 * CMake files) so it is prepended to every translation unit without a per-file import.
 */

#ifndef NULLPTR_COMPAT_H
#define NULLPTR_COMPAT_H

#if !defined(__cplusplus) && (!defined(__STDC_VERSION__) || __STDC_VERSION__ < 202311L)
#ifndef nullptr
/** @brief The C23 null pointer constant, for the pre-C23 C compilers that lack it. */
#define nullptr ((void *)0)
#endif
#endif

#endif
