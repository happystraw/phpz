/* bench_c extension for PHP */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "php.h"
#include "ext/standard/info.h"
#include "php_bench_c.h"
#include "bench_c_arginfo.h"

#ifndef ZEND_PARSE_PARAMETERS_NONE
#define ZEND_PARSE_PARAMETERS_NONE() \
	ZEND_PARSE_PARAMETERS_START(0, 0) \
	ZEND_PARSE_PARAMETERS_END()
#endif

/* {{{ 1. Empty */
PHP_FUNCTION(bench_c_empty)
{
	ZEND_PARSE_PARAMETERS_NONE();
}
/* }}} */

/* {{{ 2. Multi-param — fast Z_PARAM macro */
PHP_FUNCTION(bench_c_parse_multi)
{
	zend_long    n;
	zend_string *s;
	double       d;
	zend_bool    b;
	zval        *arr, *obj, *mixed;
	zend_long    opt = 0;
	bool         opt_is_null = 1;

	ZEND_PARSE_PARAMETERS_START(7, 8)
		Z_PARAM_LONG(n)
		Z_PARAM_STR(s)
		Z_PARAM_DOUBLE(d)
		Z_PARAM_BOOL(b)
		Z_PARAM_ARRAY(arr)
		Z_PARAM_OBJECT(obj)
		Z_PARAM_ZVAL(mixed)
		Z_PARAM_OPTIONAL
		Z_PARAM_LONG_OR_NULL(opt, opt_is_null)
	ZEND_PARSE_PARAMETERS_END();

	(void)n; (void)s; (void)d; (void)b; (void)arr; (void)obj; (void)mixed; (void)opt; (void)opt_is_null;
}
/* }}} */

/* {{{ 2b. Multi-param — zend_parse_parameters */
PHP_FUNCTION(bench_c_parse_multi_pp)
{
	zend_long  n;
	char      *s_str; size_t s_len;
	double     d;
	zend_bool  b;
	zval      *arr, *obj, *mixed;
	zend_long  opt = 0;
	bool       opt_is_null;

	if (zend_parse_parameters(ZEND_NUM_ARGS(), "lsdbaoz|l!",
		&n, &s_str, &s_len, &d, &b, &arr, &obj, &mixed, &opt, &opt_is_null) == FAILURE) {
		RETURN_THROWS();
	}

	(void)n; (void)s_str; (void)s_len; (void)d; (void)b; (void)arr; (void)obj; (void)mixed; (void)opt; (void)opt_is_null;
}
/* }}} */

/* {{{ 3. Array sum — fast Z_PARAM macro */
PHP_FUNCTION(bench_c_array_sum_fast)
{
	zval *arr;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_ARRAY(arr)
	ZEND_PARSE_PARAMETERS_END();

	zend_long sum = 0;
	zval *val;

	ZEND_HASH_FOREACH_VAL(Z_ARRVAL_P(arr), val) {
		if (Z_TYPE_P(val) == IS_LONG) {
			sum += Z_LVAL_P(val);
		}
	} ZEND_HASH_FOREACH_END();

	RETURN_LONG(sum);
}
/* }}} */

/* {{{ 3b. Array sum — zend_parse_parameters */
PHP_FUNCTION(bench_c_array_sum_parse)
{
	zval *arr;

	if (zend_parse_parameters(ZEND_NUM_ARGS(), "a", &arr) == FAILURE) {
		RETURN_THROWS();
	}

	zend_long sum = 0;
	zval *val;

	ZEND_HASH_FOREACH_VAL(Z_ARRVAL_P(arr), val) {
		if (Z_TYPE_P(val) == IS_LONG) {
			sum += Z_LVAL_P(val);
		}
	} ZEND_HASH_FOREACH_END();

	RETURN_LONG(sum);
}
/* }}} */

/* {{{ PHP_RINIT_FUNCTION */
PHP_RINIT_FUNCTION(bench_c)
{
#if defined(ZTS) && defined(COMPILE_DL_BENCH_C)
	ZEND_TSRMLS_CACHE_UPDATE();
#endif

	return SUCCESS;
}
/* }}} */

/* {{{ PHP_MINFO_FUNCTION */
PHP_MINFO_FUNCTION(bench_c)
{
	php_info_print_table_start();
	php_info_print_table_header(2, "bench_c support", "enabled");
	php_info_print_table_end();
}
/* }}} */

/* {{{ bench_c_module_entry */
zend_module_entry bench_c_module_entry = {
	STANDARD_MODULE_HEADER,
	"bench_c",					/* Extension name */
	ext_functions,					/* zend_function_entry */
	NULL,							/* PHP_MINIT - Module initialization */
	NULL,							/* PHP_MSHUTDOWN - Module shutdown */
	PHP_RINIT(bench_c),			/* PHP_RINIT - Request initialization */
	NULL,							/* PHP_RSHUTDOWN - Request shutdown */
	PHP_MINFO(bench_c),			/* PHP_MINFO - Module info */
	PHP_BENCH_C_VERSION,		/* Version */
	STANDARD_MODULE_PROPERTIES
};
/* }}} */

#ifdef COMPILE_DL_BENCH_C
# ifdef ZTS
ZEND_TSRMLS_CACHE_DEFINE()
# endif
ZEND_GET_MODULE(bench_c)
#endif
