#ifndef PHPZ_TRANSLATE_C_COMPAT_H
#define PHPZ_TRANSLATE_C_COMPAT_H

// Workaround for windows.h: https://codeberg.org/ziglang/translate-c/issues/307
#if defined(PHP_WIN32) || defined(_WIN32) || defined(WIN32)
# ifndef WIN32_LEAN_AND_MEAN
# define WIN32_LEAN_AND_MEAN
# endif

# ifndef NOMINMAX
# define NOMINMAX
# endif

# ifndef DECLSPEC_NOINITALL
# define DECLSPEC_NOINITALL
# endif

# ifndef ENABLE_INTSAFE_SIGNED_FUNCTIONS
# define ENABLE_INTSAFE_SIGNED_FUNCTIONS
# endif

# ifndef __assume
# define __assume(expr) ((void)0)
# endif

# include <math.h>
# ifdef _CLASS_ARG
# undef _CLASS_ARG
# define _CLASS_ARG(_Val) (sizeof((_Val) + (float)0) == sizeof(float) ? 'f' : sizeof((_Val) + (double)0) == sizeof(double) ? 'd' : 'l')
# endif
#endif


// FIXME: regression in translate_c
#include "Zend/zend_portability.h"
#ifdef ZEND_ATTRIBUTE_COLD_LABEL
# undef ZEND_ATTRIBUTE_COLD_LABEL
# define ZEND_ATTRIBUTE_COLD_LABEL
#endif

#endif // PHPZ_TRANSLATE_C_COMPAT_H
