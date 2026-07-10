#ifndef PHPZ_COMPAT_H
#define PHPZ_COMPAT_H

#if defined(_MSC_VER) && defined(__clang__) && !defined(ZEND_PORTABILITY_H)
#include "main/php_version.h"

#if PHP_VERSION_ID >= 80500
/* Match PHP's Clang toolset by using compiler overflow builtins. */
#define PHP_HAVE_BUILTIN_SADDL_OVERFLOW 1
#define PHP_HAVE_BUILTIN_SADDLL_OVERFLOW 1
#define PHP_HAVE_BUILTIN_SSUBL_OVERFLOW 1
#define PHP_HAVE_BUILTIN_SSUBLL_OVERFLOW 1
#define PHP_HAVE_BUILTIN_SMULL_OVERFLOW 1
#define PHP_HAVE_BUILTIN_SMULLL_OVERFLOW 1
#endif

/* PHP's Windows headers disable parts of the MSVC path, including
 * ZEND_FASTCALL in PHP <= 8.3 and <intrin.h>, when __clang__ is defined.
 * Parse zend_portability.h as MSVC to match PHP's ABI, then restore __clang__. */
#undef __clang__
#include "Zend/zend_portability.h"
#define __clang__
#endif
#endif // PHPZ_COMPAT_H
