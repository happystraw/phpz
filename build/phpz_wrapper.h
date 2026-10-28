#ifndef PHPZ_WRAPPER_H
#define PHPZ_WRAPPER_H

/* Use the active PHP headers as the source of ZPP diagnostic wording. */
static zend_always_inline const char *phpz_expected_type_description(zend_expected_type expected) {
    static const char *const descriptions[] = {
        Z_EXPECTED_TYPES(Z_EXPECTED_TYPE_STR)
    };
    ZEND_ASSERT((unsigned int) expected < Z_EXPECTED_LAST);
    return descriptions[expected];
}

static zend_always_inline php_stream *phpz_stream_open(const char *path, const char *mode, int options) {
    return php_stream_open_wrapper(path, mode, options, NULL);
}

static zend_always_inline php_stream *phpz_stream_opendir(const char *path, int options) {
    return php_stream_opendir(path, options, NULL);
}

bool phpz_stream_is_persistent(php_stream *stream);
void phpz_stream_to_zval(php_stream *stream, zval *value);

/* Keep PHP's HASH_NOMEM sentinel casts in C; translate-c cannot lower them. */
void *phpz_hash_index_update_ptr(HashTable *ht, zend_ulong h, void *data);

static zend_always_inline zend_result phpz_stream_copy_to_stream(php_stream *src, php_stream *dest, size_t maxlen, size_t *len) {
    return php_stream_copy_to_stream_ex(src, dest, maxlen, len);
}

static zend_always_inline const char *phpz_module_build_id(void) {
    return ZEND_MODULE_BUILD_ID;
}

#if defined(ZTS) && defined(PHPZ_STATIC_TSRMLS_CACHE)
void *phpz_static_tsrmls_cache_get(void);
void phpz_static_tsrmls_cache_update(void);
void phpz_static_tsrmls_cache_clear(void);
#endif

#ifndef ZTS
/* ZTS globals are reached through tsrm.zig. */
static zend_always_inline zend_executor_globals *phpz_executor_globals(void) {
    return &executor_globals;
}

static zend_always_inline zend_compiler_globals *phpz_compiler_globals(void) {
    return &compiler_globals;
}

static zend_always_inline php_core_globals *phpz_core_globals(void) {
    return &core_globals;
}

static zend_always_inline sapi_globals_struct *phpz_sapi_globals(void) {
    return &sapi_globals;
}

static zend_always_inline php_file_globals *phpz_file_globals(void) {
    return &file_globals;
}
#endif

#ifdef ZTS
typedef ts_rsrc_id phpz_rsrc_id;
#else
typedef int phpz_rsrc_id;
#endif

typedef void (*phpz_zend_try_callback)(void *);

bool phpz_zend_try_catch(phpz_zend_try_callback callback, void *ctx);
bool phpz_zend_first_try_catch(phpz_zend_try_callback callback, void *ctx);

static ZEND_COLD ZEND_NORETURN zend_always_inline void phpz_zend_bailout() {
  zend_bailout();
}

static zend_always_inline void phpz_zval_zval(zval *z, zval *src, bool copy, bool dtor_src) {
    ZVAL_ZVAL(z, src, copy, dtor_src);
}

static zend_always_inline void phpz_zval_copy_value(zval *z, const zval *src) {
    ZVAL_COPY_VALUE(z, src);
}

static zend_always_inline void phpz_zval_copy(zval *z, const zval *src) {
    ZVAL_COPY(z, src);
}

static zend_always_inline void phpz_zval_copy_deref(zval *z, zval *src) {
    ZVAL_COPY_DEREF(z, src);
}

static zend_always_inline void phpz_zval_make_ref(zval *value) {
    ZVAL_MAKE_REF(value);
}

static zend_always_inline zend_reference *phpz_reference_new_empty(void) {
    zval value;
    ZVAL_NEW_EMPTY_REF(&value);
    return Z_REF(value);
}

/* Consumes one owned value, including when a typed assignment fails. */
static zend_always_inline void phpz_reference_assign(zend_reference *ref, zval *value) {
    if (UNEXPECTED(ZEND_REF_HAS_TYPE_SOURCES(ref)) &&
        UNEXPECTED(!zend_verify_ref_assignable_zval(ref, value, ZEND_ARG_USES_STRICT_TYPES()))) {
        zval_ptr_dtor(value);
        return;
    }
    /* The inner value is not a reference; its type constraints were checked above.
     * Zend's variable assignment writes first, then destroys the old payload. */
#if PHP_VERSION_ID >= 80500
    zend_safe_assign_to_variable_noref(&ref->val, value);
#else
    zend_assign_to_variable(&ref->val, value, IS_TMP_VAR, false);
#endif
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

/* zend_release_properties is a statement macro before PHP 8.6. */
static zend_always_inline void phpz_release_properties(HashTable *properties) {
    zend_release_properties(properties);
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

static ZEND_NAMED_FUNCTION(phpz_guard_scope_constructor) {
    zend_throw_error(NULL, "Instantiation of a Phpz guard scope is not allowed");
}

static zend_always_inline zend_class_entry *phpz_register_guard_scope_class(int module_number) {
    ZEND_BEGIN_ARG_INFO_EX(arginfo_guard_ctor, 0, 0, 0)
    ZEND_END_ARG_INFO()

    static const zend_function_entry guard_scope_methods[] = {
        ZEND_NAMED_ME(__construct, phpz_guard_scope_constructor, arginfo_guard_ctor, ZEND_ACC_PRIVATE)
        ZEND_FE_END
    };

    char name[21];
    int length = snprintf(name, sizeof(name), "PhpzGuard@%d", module_number);
    zend_class_entry ce, *entry;
    INIT_CLASS_ENTRY_EX(ce, name, length, guard_scope_methods);
#if PHP_VERSION_ID >= 80400
    entry = zend_register_internal_class_with_flags(&ce, NULL, ZEND_ACC_FINAL|ZEND_ACC_NO_DYNAMIC_PROPERTIES|ZEND_ACC_NOT_SERIALIZABLE);
#else
    entry = zend_register_internal_class_ex(&ce, NULL);
    entry->ce_flags |= ZEND_ACC_FINAL|ZEND_ACC_NO_DYNAMIC_PROPERTIES|ZEND_ACC_NOT_SERIALIZABLE;
#endif
    return entry;
}

#endif // PHPZ_WRAPPER_H
