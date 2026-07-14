#ifndef PHPZ_WRAPPER_H
#define PHPZ_WRAPPER_H

static zend_always_inline const char *phpz_module_build_id(void) {
    return ZEND_MODULE_BUILD_ID;
}

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

static zend_always_inline php_file_globals *phpz_file_globals(void) {
#ifdef ZTS
#ifdef ZEND_ENABLE_STATIC_TSRMLS_CACHE
    return TSRMG_BULK_STATIC(file_globals_id, php_file_globals *);
#else
    return TSRMG_BULK(file_globals_id, php_file_globals *);
#endif
#else
    return &file_globals;
#endif
}

#ifdef ZTS
typedef ts_rsrc_id phpz_rsrc_id;
#else
typedef int phpz_rsrc_id;
#endif

static zend_always_inline void *phpz_tsrmg_bulk(phpz_rsrc_id id) {
#ifdef ZTS
#ifdef ZEND_ENABLE_STATIC_TSRMLS_CACHE
    return TSRMG_BULK_STATIC(id, void *);
#else
    return TSRMG_BULK(id, void *);
#endif
#else
    (void) id;
    return NULL;
#endif
}

typedef void (*phpz_zend_try_callback)(void *);

bool phpz_zend_try_catch(phpz_zend_try_callback callback, void *ctx);
bool phpz_zend_first_try_catch(phpz_zend_try_callback callback, void *ctx);

static ZEND_COLD ZEND_NORETURN zend_always_inline void phpz_zend_bailout() {
  zend_bailout();
}

static zend_always_inline void phpz_zval_zval(zval *z, zval *src, bool copy, bool dtor_src) {
    ZVAL_ZVAL(z, src, copy, dtor_src);
}

static zend_always_inline void phpz_separate_array(zval *z) {
    SEPARATE_ARRAY(z);
}

/* Bridge helpers for anonymous unions.
 * translate-c numbers unnamed unions (unnamed_0, unnamed_1, ...),
 * which break when PHP headers change union layout. These inline
 * wrappers give translate-c stable symbol names to bind against. */

static zend_always_inline zval *phpz_hash_table_get_ar_packed(HashTable *ht) {
    return ht->arPacked;
}

static zend_always_inline void phpz_class_entry_set_create_object(zend_class_entry *ce, zend_object* (*handler)(zend_class_entry *)) {
    ce->create_object = handler;
}

static zend_always_inline zend_class_entry *phpz_class_entry_get_parent(zend_class_entry *ce) {
    return ce->parent;
}

static zend_always_inline zend_class_entry *phpz_class_entry_get_interface(zend_class_entry *ce, uint32_t index) {
    return ce->interfaces[index];
}

#endif // PHPZ_WRAPPER_H
