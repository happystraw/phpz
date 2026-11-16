#include "phpz.h"

php_json_error_code phpz_json_last_error(void) {
#if PHP_VERSION_ID >= 80600
    return JSON_G(error_details).code;
#else
    return JSON_G(error_code);
#endif
}

void *phpz_hash_index_update_ptr(HashTable *ht, zend_ulong h, void *data) {
    return zend_hash_index_update_ptr(ht, h, data);
}

bool phpz_stream_is_persistent(php_stream *stream) {
    return php_stream_is_persistent(stream);
}

void phpz_stream_to_zval(php_stream *stream, zval *value) {
    php_stream_to_zval(stream, value);
}

#if defined(ZTS) && defined(PHPZ_STATIC_TSRMLS_CACHE)
#ifdef ZEND_COMPILE_DL_EXT
ZEND_TSRMLS_CACHE_DEFINE()
#endif

void *phpz_static_tsrmls_cache_get(void) {
    return ZEND_TSRMLS_CACHE;
}

void phpz_static_tsrmls_cache_update(void) {
    ZEND_TSRMLS_CACHE_UPDATE();
}

void phpz_static_tsrmls_cache_clear(void) {
    ZEND_TSRMLS_CACHE = NULL;
}
#endif

bool phpz_zend_try_catch(phpz_zend_try_callback callback, void *ctx) {
    zend_try {
        callback(ctx);
    } zend_catch {
        return true;
    } zend_end_try();
    return false;
}

bool phpz_zend_first_try_catch(phpz_zend_try_callback callback, void *ctx) {
    zend_first_try {
        callback(ctx);
    } zend_catch {
        return true;
    } zend_end_try();
    return false;
}
