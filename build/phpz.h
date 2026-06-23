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

#include "php.h"
#include "Zend/zend_API.h"
#include "Zend/zend_exceptions.h"
#include "Zend/zend_enum.h"
#include "ext/standard/info.h"
#include "main/SAPI.h"

static zend_always_inline zend_executor_globals *phpz_executor_globals(void) {
#ifdef ZTS
#ifdef ZEND_ENABLE_STATIC_TSRMLS_CACHE
    return (zend_executor_globals *) (((char *) TSRMLS_CACHE) + executor_globals_offset);
#else
    return (zend_executor_globals *) (((char *) tsrm_get_ls_cache()) + executor_globals_offset);
#endif
#else
    return &executor_globals;
#endif
}

static zend_always_inline zend_compiler_globals *phpz_compiler_globals(void) {
#ifdef ZTS
#ifdef ZEND_ENABLE_STATIC_TSRMLS_CACHE
    return (zend_compiler_globals *) (((char *) TSRMLS_CACHE) + compiler_globals_offset);
#else
    return (zend_compiler_globals *) (((char *) tsrm_get_ls_cache()) + compiler_globals_offset);
#endif
#else
    return &compiler_globals;
#endif
}

static zend_always_inline php_core_globals *phpz_core_globals(void) {
#ifdef ZTS
#ifdef ZEND_ENABLE_STATIC_TSRMLS_CACHE
    return (php_core_globals *) (((char *) TSRMLS_CACHE) + core_globals_offset);
#else
    return (php_core_globals *) (((char *) tsrm_get_ls_cache()) + core_globals_offset);
#endif
#else
    return &core_globals;
#endif
}

static zend_always_inline sapi_globals_struct *phpz_sapi_globals(void) {
#ifdef ZTS
#ifdef ZEND_ENABLE_STATIC_TSRMLS_CACHE
    return (sapi_globals_struct *) (((char *) TSRMLS_CACHE) + sapi_globals_offset);
#else
    return (sapi_globals_struct *) (((char *) tsrm_get_ls_cache()) + sapi_globals_offset);
#endif
#else
    return &sapi_globals;
#endif
}

static zend_always_inline void phpz_zval_zval(zval *z, zval *src, bool copy, bool dtor_src) {
    ZVAL_ZVAL(z, src, copy, dtor_src);
}

/* Bridge helpers for zend_class_entry anonymous unions.
 * translate-c numbers unnamed unions (unnamed_0, unnamed_1, ...),
 * which break when PHP headers change union layout. These inline
 * wrappers give translate-c stable symbol names to bind against. */

static zend_always_inline void phpz_class_entry_set_create_object(zend_class_entry *ce, zend_object* (*handler)(zend_class_entry *)) {
    ce->create_object = handler;
}

static zend_always_inline zend_class_entry *phpz_class_entry_get_parent(zend_class_entry *ce) {
    return ce->parent;
}

static zend_always_inline zend_class_entry *phpz_class_entry_get_interface(zend_class_entry *ce, uint32_t index) {
    return ce->interfaces[index];
}

#endif
