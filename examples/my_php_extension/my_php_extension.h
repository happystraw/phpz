// for module
#include "php.h"
#include "Zend/zend_API.h"
#include "ext/standard/info.h"
#include "Zend/zend_interfaces.h"
#include "my_php_extension_arginfo.h"

// only for static build (in source tree)
extern zend_module_entry my_php_extension_module_entry;
#define phpext_my_php_extension_ptr &my_php_extension_module_entry
