#ifndef PHPZ_H
#define PHPZ_H

#include "php.h"
#include "Zend/zend_API.h"
#include "Zend/zend_exceptions.h"

extern zend_always_inline zend_string *zig_zend_string_init(const char *str, size_t len, bool persistent);

#endif
