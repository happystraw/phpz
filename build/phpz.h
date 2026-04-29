#ifndef PHPZ_H
#define PHPZ_H

/*
 * Workaround: skip <arm_neon.h> on aarch64.
 *
 * Why it's needed:
 *   On aarch64, `php.h` -> `Zend/zend_types.h` unconditionally includes
 *   <arm_neon.h>, which pulls in Clang's <arm_vector_types.h>. Those
 *   headers use the `__mfp8` builtin type and thousands of
 *   `__builtin_neon_*` intrinsics that Zig's translate-c (aro) cannot
 *   parse, so binding generation fails before any of our code is reached.
 *
 * Why it's safe:
 *   PHP only uses NEON inside macro bodies (e.g. HT_HASH_RESET in
 *   zend_types.h) and static inline functions. translate-c only parses
 *   top-level declarations (typedefs / structs / function prototypes),
 *   none of which reference NEON types. The macros are expanded later by
 *   the real C compiler when the extension is built, where <arm_neon.h>
 *   is included normally and handled by native Clang.
 *
 * How it works:
 *   Predefining the headers' own include guards makes their bodies expand
 *   to nothing during translate-c, while the C build still sees them
 *   unchanged.
 */
#if defined(__aarch64__) || defined(_M_ARM64)
#define __ARM_NEON_H
#endif

#include "Zend/zend_API.h"
#include "Zend/zend_exceptions.h"
#include "php.h"

#endif
