#ifndef PHPZ_H
#define PHPZ_H

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
