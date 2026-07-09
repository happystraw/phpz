#include "phpz.h"

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
