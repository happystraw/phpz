#ifndef PHPZ_TRANSLATE_C_COMPAT_H
#define PHPZ_TRANSLATE_C_COMPAT_H

// Workaround for windows.h: https://codeberg.org/ziglang/translate-c/issues/307
#if defined(PHP_WIN32) || defined(_WIN32) || defined(WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#ifndef NOMINMAX
#define NOMINMAX
#endif

#ifndef DECLSPEC_NOINITALL
#define DECLSPEC_NOINITALL
#endif

#ifndef __assume
#define __assume(expr) ((void)0)
#endif

#include <math.h>
#ifdef _CLASS_ARG
#undef _CLASS_ARG
#define _CLASS_ARG(_Val) (sizeof((_Val) + (float)0) == sizeof(float) ? 'f' : sizeof((_Val) + (double)0) == sizeof(double) ? 'd' : 'l')
#endif
#endif

#if defined(PHP_WIN32)
#include "main/php_version.h"

#if PHP_VERSION_ID >= 80500
/* Match PHP's Clang toolset by using compiler overflow builtins. translate-c
 * currently lowers only their generic forms, so map the typed variants. */
#define PHP_HAVE_BUILTIN_SADDL_OVERFLOW 1
#define PHP_HAVE_BUILTIN_SADDLL_OVERFLOW 1
#define PHP_HAVE_BUILTIN_SSUBL_OVERFLOW 1
#define PHP_HAVE_BUILTIN_SSUBLL_OVERFLOW 1
#define PHP_HAVE_BUILTIN_SMULL_OVERFLOW 1
#define PHP_HAVE_BUILTIN_SMULLL_OVERFLOW 1
#define __builtin_saddl_overflow __builtin_add_overflow
#define __builtin_saddll_overflow __builtin_add_overflow
#define __builtin_ssubl_overflow __builtin_sub_overflow
#define __builtin_ssubll_overflow __builtin_sub_overflow
#define __builtin_smull_overflow __builtin_mul_overflow
#define __builtin_smulll_overflow __builtin_mul_overflow
#endif

#if PHP_VERSION_ID >= 80400 && PHP_VERSION_ID < 80500 \
 && defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
/* PHP 8.4 assumes C11 stddef.h provides max_align_t, but Windows UCRT does not.
 * Match PHP 8.5 by making zend_max_align_t use the Windows fallback union. */
#define max_align_t union { \
    char c; short s; int i; long l; long long ll; \
    float f; double d; long double ld; void *p; void (*fun)(void); \
}
#endif
#endif

#if defined(_MSC_VER) && defined(__clang__)
#undef __clang__
#include "Zend/zend_portability.h"
#define __clang__
#else
#include "Zend/zend_portability.h"
#endif

// FIXME: regression in translate_c
#ifdef ZEND_ATTRIBUTE_COLD_LABEL
#undef ZEND_ATTRIBUTE_COLD_LABEL
#define ZEND_ATTRIBUTE_COLD_LABEL
#endif

#endif // PHPZ_TRANSLATE_C_COMPAT_H
