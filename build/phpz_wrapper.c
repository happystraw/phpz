#include "phpz.h"

bool phpz_stream_is_persistent(php_stream *stream) {
    return php_stream_is_persistent(stream);
}

void phpz_stream_to_zval(php_stream *stream, zval *value) {
    php_stream_to_zval(stream, value);
}

#if defined(ZTS) && defined(PHPZ_STATIC_TSRMLS_CACHE)
void *phpz_tsrm_ls_cache(void) {
    return TSRMLS_CACHE;
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
