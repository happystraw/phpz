/* bench_c extension for PHP */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <math.h>

#include "php.h"
#include "ext/standard/info.h"
#include "zend_exceptions.h"
#include "php_bench_c.h"
#include "bench_c_arginfo.h"

#ifndef ZEND_PARSE_PARAMETERS_NONE
#define ZEND_PARSE_PARAMETERS_NONE() \
	ZEND_PARSE_PARAMETERS_START(0, 0) \
	ZEND_PARSE_PARAMETERS_END()
#endif

#define BENCH_MAX_BUILD (1 << 24)

ZEND_BEGIN_MODULE_GLOBALS(bench_c)
	zend_long counter;
ZEND_END_MODULE_GLOBALS(bench_c)

ZEND_DECLARE_MODULE_GLOBALS(bench_c)

#define BENCH_C_G(v) ZEND_MODULE_GLOBALS_ACCESSOR(bench_c, v)

PHP_FUNCTION(bench_c_empty)
{
	ZEND_PARSE_PARAMETERS_NONE();
}

PHP_FUNCTION(bench_c_parse_multi)
{
	zend_long    n;
	zend_string *s;
	double       d;
	bool         b;
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

PHP_FUNCTION(bench_c_parse_multi_pp)
{
	zend_long  n;
	char      *s_str; size_t s_len;
	double     d;
	bool       b;
	zval      *arr, *obj, *mixed;
	zend_long  opt = 0;
	bool       opt_is_null;

	if (zend_parse_parameters(ZEND_NUM_ARGS(), "lsdbaoz|l!",
		&n, &s_str, &s_len, &d, &b, &arr, &obj, &mixed, &opt, &opt_is_null) == FAILURE) {
		RETURN_THROWS();
	}

	(void)n; (void)s_str; (void)s_len; (void)d; (void)b; (void)arr; (void)obj; (void)mixed; (void)opt; (void)opt_is_null;
}

static zend_always_inline zend_long bench_c_sum_values(HashTable *ht)
{
	zend_long sum = 0;
	zval *val;

	ZEND_HASH_FOREACH_VAL(ht, val) {
		if (Z_TYPE_P(val) == IS_LONG) {
			sum += Z_LVAL_P(val);
		}
	} ZEND_HASH_FOREACH_END();

	return sum;
}

PHP_FUNCTION(bench_c_array_sum_fast)
{
	zval *arr;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_ARRAY(arr)
	ZEND_PARSE_PARAMETERS_END();

	RETURN_LONG(bench_c_sum_values(Z_ARRVAL_P(arr)));
}

PHP_FUNCTION(bench_c_array_sum_parse)
{
	zval *arr;

	if (zend_parse_parameters(ZEND_NUM_ARGS(), "a", &arr) == FAILURE) {
		RETURN_THROWS();
	}

	RETURN_LONG(bench_c_sum_values(Z_ARRVAL_P(arr)));
}

PHP_FUNCTION(bench_c_add)
{
	zend_long a, b;

	ZEND_PARSE_PARAMETERS_START(2, 2)
		Z_PARAM_LONG(a)
		Z_PARAM_LONG(b)
	ZEND_PARSE_PARAMETERS_END();

	RETURN_LONG((zend_long)((zend_ulong)a + (zend_ulong)b));
}

PHP_FUNCTION(bench_c_muladd)
{
	double a, b, c;

	ZEND_PARSE_PARAMETERS_START(3, 3)
		Z_PARAM_DOUBLE(a)
		Z_PARAM_DOUBLE(b)
		Z_PARAM_DOUBLE(c)
	ZEND_PARSE_PARAMETERS_END();

	RETURN_DOUBLE(a * b + c);
}

PHP_FUNCTION(bench_c_str_len)
{
	zend_string *s;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_STR(s)
	ZEND_PARSE_PARAMETERS_END();

	RETURN_LONG((zend_long)ZSTR_LEN(s));
}

PHP_FUNCTION(bench_c_int_to_string)
{
	zend_long n;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_LONG(n)
	ZEND_PARSE_PARAMETERS_END();

	RETURN_STR(zend_long_to_str(n));
}

PHP_FUNCTION(bench_c_str_upper)
{
	zend_string *s;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_STR(s)
	ZEND_PARSE_PARAMETERS_END();

	size_t len = ZSTR_LEN(s);
	zend_string *result = zend_string_alloc(len, 0);
	const unsigned char *src = (const unsigned char *)ZSTR_VAL(s);
	unsigned char *dst = (unsigned char *)ZSTR_VAL(result);
	for (size_t i = 0; i < len; i++) {
		unsigned char ch = src[i];
		dst[i] = (ch >= 'a' && ch <= 'z') ? (unsigned char)(ch - ('a' - 'A')) : ch;
	}
	dst[len] = '\0';
	RETURN_NEW_STR(result);
}

PHP_FUNCTION(bench_c_array_sum_assoc)
{
	HashTable *ht;
	zend_string *key;
	zval *val;
	zend_long sum = 0;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_ARRAY_HT(ht)
	ZEND_PARSE_PARAMETERS_END();

	ZEND_HASH_FOREACH_STR_KEY_VAL(ht, key, val) {
		if (key) {
			sum += (zend_long)ZSTR_LEN(key);
		}
		if (Z_TYPE_P(val) == IS_LONG) {
			sum += Z_LVAL_P(val);
		}
	} ZEND_HASH_FOREACH_END();

	RETURN_LONG(sum);
}

PHP_FUNCTION(bench_c_array_build)
{
	zend_long n;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_LONG(n)
	ZEND_PARSE_PARAMETERS_END();

	if (n < 0 || n > BENCH_MAX_BUILD) {
		zend_argument_value_error(1, "must be between 0 and 16777216");
		RETURN_THROWS();
	}

	array_init_size(return_value, (uint32_t)n);
	zend_hash_real_init_packed(Z_ARRVAL_P(return_value));
	ZEND_HASH_FILL_PACKED(Z_ARRVAL_P(return_value)) {
		for (zend_long i = 0; i < n; i++) {
			ZEND_HASH_FILL_SET_LONG(i);
			ZEND_HASH_FILL_NEXT();
		}
	} ZEND_HASH_FILL_END();
}

PHP_FUNCTION(bench_c_hash_lookup)
{
	HashTable *ht;
	zend_string *key;

	ZEND_PARSE_PARAMETERS_START(2, 2)
		Z_PARAM_ARRAY_HT(ht)
		Z_PARAM_STR(key)
	ZEND_PARSE_PARAMETERS_END();

	zval *value = zend_hash_find(ht, key);
	if (!value) {
		RETURN_NULL();
	}
	RETURN_COPY_DEREF(value);
}

PHP_FUNCTION(bench_c_array_identity)
{
	zval *arr;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_ARRAY(arr)
	ZEND_PARSE_PARAMETERS_END();

	RETURN_COPY(arr);
}

PHP_FUNCTION(bench_c_throw)
{
	zend_long code;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_LONG(code)
	ZEND_PARSE_PARAMETERS_END();

	zend_throw_exception(zend_ce_exception, "boom", code);
	RETURN_THROWS();
}

PHP_FUNCTION(bench_c_split)
{
	zend_string *s, *sep;

	ZEND_PARSE_PARAMETERS_START(2, 2)
		Z_PARAM_STR(s)
		Z_PARAM_STR(sep)
	ZEND_PARSE_PARAMETERS_END();

	if (ZSTR_LEN(sep) == 0) {
		zend_argument_value_error(2, "cannot be empty");
		RETURN_THROWS();
	}

	array_init(return_value);
	const char *p = ZSTR_VAL(s);
	const char *end = p + ZSTR_LEN(s);
	const char *found;
	while ((found = zend_memnstr(p, ZSTR_VAL(sep), ZSTR_LEN(sep), end)) != NULL) {
		add_next_index_stringl(return_value, p, (size_t)(found - p));
		p = found + ZSTR_LEN(sep);
	}
	add_next_index_stringl(return_value, p, (size_t)(end - p));
}

PHP_FUNCTION(bench_c_counter)
{
	ZEND_PARSE_PARAMETERS_NONE();

	RETURN_LONG(++BENCH_C_G(counter));
}

PHP_FUNCTION(bench_c_invoke)
{
	zend_fcall_info fci;
	zend_fcall_info_cache fcc;
	zval *arg;

	ZEND_PARSE_PARAMETERS_START(2, 2)
		Z_PARAM_FUNC(fci, fcc)
		Z_PARAM_ZVAL(arg)
	ZEND_PARSE_PARAMETERS_END();

	fci.retval = return_value;
	fci.params = arg;
	fci.param_count = 1;
	zend_call_function(&fci, &fcc);
}

typedef struct {
	double x;
	double y;
	zend_object std;
} bench_c_point;

static zend_class_entry *bench_c_point_ce;
static zend_object_handlers bench_c_point_handlers;

static zend_always_inline bench_c_point *bench_c_point_from(zend_object *obj)
{
	return (bench_c_point *)((char *)obj - XtOffsetOf(bench_c_point, std));
}

static zend_object *bench_c_point_create(zend_class_entry *ce)
{
	bench_c_point *point = zend_object_alloc(sizeof(bench_c_point), ce);
	point->x = 0;
	point->y = 0;
	zend_object_std_init(&point->std, ce);
	object_properties_init(&point->std, ce);
	point->std.handlers = &bench_c_point_handlers;
	return &point->std;
}

PHP_METHOD(BenchCPoint, __construct)
{
	double x, y;

	ZEND_PARSE_PARAMETERS_START(2, 2)
		Z_PARAM_DOUBLE(x)
		Z_PARAM_DOUBLE(y)
	ZEND_PARSE_PARAMETERS_END();

	bench_c_point *point = bench_c_point_from(Z_OBJ_P(ZEND_THIS));
	point->x = x;
	point->y = y;
}

PHP_METHOD(BenchCPoint, length)
{
	ZEND_PARSE_PARAMETERS_NONE();

	bench_c_point *point = bench_c_point_from(Z_OBJ_P(ZEND_THIS));
	RETURN_DOUBLE(sqrt(point->x * point->x + point->y * point->y));
}

PHP_METHOD(BenchCPoint, translate)
{
	double dx, dy;

	ZEND_PARSE_PARAMETERS_START(2, 2)
		Z_PARAM_DOUBLE(dx)
		Z_PARAM_DOUBLE(dy)
	ZEND_PARSE_PARAMETERS_END();

	bench_c_point *point = bench_c_point_from(Z_OBJ_P(ZEND_THIS));
	point->x += dx;
	point->y += dy;
}

PHP_MINIT_FUNCTION(bench_c)
{
	bench_c_point_ce = register_class_BenchCPoint();
	bench_c_point_ce->create_object = bench_c_point_create;
	memcpy(&bench_c_point_handlers, &std_object_handlers, sizeof(zend_object_handlers));
	bench_c_point_handlers.offset = XtOffsetOf(bench_c_point, std);
	bench_c_point_handlers.clone_obj = NULL;
	return SUCCESS;
}

PHP_GINIT_FUNCTION(bench_c)
{
#if defined(ZTS) && defined(COMPILE_DL_BENCH_C)
	ZEND_TSRMLS_CACHE_UPDATE();
#endif
	bench_c_globals->counter = 0;
}

PHP_RINIT_FUNCTION(bench_c)
{
#if defined(ZTS) && defined(COMPILE_DL_BENCH_C)
	ZEND_TSRMLS_CACHE_UPDATE();
#endif
	BENCH_C_G(counter) = 0;

	return SUCCESS;
}

PHP_MINFO_FUNCTION(bench_c)
{
	php_info_print_table_start();
	php_info_print_table_header(2, "bench_c support", "enabled");
	php_info_print_table_end();
}

zend_module_entry bench_c_module_entry = {
	STANDARD_MODULE_HEADER,
	"bench_c",
	ext_functions,
	PHP_MINIT(bench_c),
	NULL,
	PHP_RINIT(bench_c),
	NULL,
	PHP_MINFO(bench_c),
	PHP_BENCH_C_VERSION,
	PHP_MODULE_GLOBALS(bench_c),
	PHP_GINIT(bench_c),
	NULL,
	NULL,
	STANDARD_MODULE_PROPERTIES_EX
};

#ifdef COMPILE_DL_BENCH_C
# ifdef ZTS
ZEND_TSRMLS_CACHE_DEFINE()
# endif
ZEND_GET_MODULE(bench_c)
#endif
