#ifndef PHPZ_H
#define PHPZ_H

// compatibility
#ifdef PHPZ_TRANSLATE_C
#include "phpz_translate_c_compat.h"
#else
#include "phpz_compat.h"
#endif

// core
#include "php.h"
#include <signal.h>
#include "Zend/zend_API.h"
#include "Zend/zend_closures.h"
#include "Zend/zend_exceptions.h"
#include "Zend/zend_enum.h"
#include "Zend/zend_observer.h"
#include "ext/standard/file.h"
#include "ext/standard/info.h"
#include "main/SAPI.h"
#include "main/php_main.h"
#include "main/php_variables.h"

// wrapper
#include "phpz_wrapper.h"

#endif // PHPZ_H
