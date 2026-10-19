/* bench_cpp extension for PHP, the C++ counterpart of bench_c */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <charconv>
#include <cmath>
#include <cstddef>
#include <string_view>

extern "C" {
#include "php.h"
#include "ext/standard/info.h"
#include "zend_exceptions.h"
}

#include "php_bench_cpp.h"
#include "bench_cpp_arginfo.h"

#ifndef ZEND_PARSE_PARAMETERS_NONE
#define ZEND_PARSE_PARAMETERS_NONE() \
	ZEND_PARSE_PARAMETERS_START(0, 0) \
	ZEND_PARSE_PARAMETERS_END()
#endif

ZEND_BEGIN_MODULE_GLOBALS(bench_cpp)
	zend_long counter;
ZEND_END_MODULE_GLOBALS(bench_cpp)

ZEND_DECLARE_MODULE_GLOBALS(bench_cpp)

#define BENCH_CPP_G(v) ZEND_MODULE_GLOBALS_ACCESSOR(bench_cpp, v)

namespace {

constexpr zend_long max_build = zend_long{1} << 24;

inline std::string_view view(const zend_string *s) noexcept
{
	return {ZSTR_VAL(s), ZSTR_LEN(s)};
}

inline zend_long sum_values(HashTable *ht) noexcept
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

struct Point {
	double x;
	double y;
	zend_object std;

	static Point *from(zend_object *obj) noexcept
	{
		return reinterpret_cast<Point *>(reinterpret_cast<char *>(obj) - offsetof(Point, std));
	}

	static Point *from(zval *zv) noexcept
	{
		return from(Z_OBJ_P(zv));
	}
};

zend_class_entry *point_ce;
zend_object_handlers point_handlers;

zend_object *point_create(zend_class_entry *ce)
{
	auto *point = static_cast<Point *>(zend_object_alloc(sizeof(Point), ce));
	point->x = 0;
	point->y = 0;
	zend_object_std_init(&point->std, ce);
	object_properties_init(&point->std, ce);
	point->std.handlers = &point_handlers;
	return &point->std;
}

} // namespace

PHP_FUNCTION(bench_cpp_empty)
{
	ZEND_PARSE_PARAMETERS_NONE();
}

PHP_FUNCTION(bench_cpp_parse_multi)
{
	zend_long n;
	zend_string *s;
	double d;
	bool b;
	zval *arr, *obj, *mixed;
	zend_long opt = 0;
	bool opt_is_null = true;

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

PHP_FUNCTION(bench_cpp_parse_multi_pp)
{
	zend_long n;
	char *s_str;
	size_t s_len;
	double d;
	bool b;
	zval *arr, *obj, *mixed;
	zend_long opt = 0;
	bool opt_is_null;

	if (zend_parse_parameters(ZEND_NUM_ARGS(), "lsdbaoz|l!",
		&n, &s_str, &s_len, &d, &b, &arr, &obj, &mixed, &opt, &opt_is_null) == FAILURE) {
		RETURN_THROWS();
	}

	(void)n; (void)s_str; (void)s_len; (void)d; (void)b; (void)arr; (void)obj; (void)mixed; (void)opt; (void)opt_is_null;
}

PHP_FUNCTION(bench_cpp_array_sum_fast)
{
	zval *arr;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_ARRAY(arr)
	ZEND_PARSE_PARAMETERS_END();

	RETURN_LONG(sum_values(Z_ARRVAL_P(arr)));
}

PHP_FUNCTION(bench_cpp_array_sum_parse)
{
	zval *arr;

	if (zend_parse_parameters(ZEND_NUM_ARGS(), "a", &arr) == FAILURE) {
		RETURN_THROWS();
	}

	RETURN_LONG(sum_values(Z_ARRVAL_P(arr)));
}

PHP_FUNCTION(bench_cpp_add)
{
	zend_long a, b;

	ZEND_PARSE_PARAMETERS_START(2, 2)
		Z_PARAM_LONG(a)
		Z_PARAM_LONG(b)
	ZEND_PARSE_PARAMETERS_END();

	RETURN_LONG(static_cast<zend_long>(static_cast<zend_ulong>(a) + static_cast<zend_ulong>(b)));
}

PHP_FUNCTION(bench_cpp_muladd)
{
	double a, b, c;

	ZEND_PARSE_PARAMETERS_START(3, 3)
		Z_PARAM_DOUBLE(a)
		Z_PARAM_DOUBLE(b)
		Z_PARAM_DOUBLE(c)
	ZEND_PARSE_PARAMETERS_END();

	RETURN_DOUBLE(a * b + c);
}

PHP_FUNCTION(bench_cpp_str_len)
{
	zend_string *s;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_STR(s)
	ZEND_PARSE_PARAMETERS_END();

	RETURN_LONG(static_cast<zend_long>(ZSTR_LEN(s)));
}

PHP_FUNCTION(bench_cpp_int_to_string)
{
	zend_long n;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_LONG(n)
	ZEND_PARSE_PARAMETERS_END();

	char buffer[24];
	auto result = std::to_chars(buffer, buffer + sizeof(buffer), n);
	RETURN_STRINGL(buffer, static_cast<size_t>(result.ptr - buffer));
}

PHP_FUNCTION(bench_cpp_str_upper)
{
	zend_string *s;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_STR(s)
	ZEND_PARSE_PARAMETERS_END();

	const size_t len = ZSTR_LEN(s);
	zend_string *result = zend_string_alloc(len, 0);
	const auto *src = reinterpret_cast<const unsigned char *>(ZSTR_VAL(s));
	auto *dst = reinterpret_cast<unsigned char *>(ZSTR_VAL(result));
	for (size_t i = 0; i < len; i++) {
		const unsigned char ch = src[i];
		dst[i] = (ch >= 'a' && ch <= 'z') ? static_cast<unsigned char>(ch - ('a' - 'A')) : ch;
	}
	dst[len] = '\0';
	RETURN_NEW_STR(result);
}

PHP_FUNCTION(bench_cpp_array_sum_assoc)
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
			sum += static_cast<zend_long>(ZSTR_LEN(key));
		}
		if (Z_TYPE_P(val) == IS_LONG) {
			sum += Z_LVAL_P(val);
		}
	} ZEND_HASH_FOREACH_END();

	RETURN_LONG(sum);
}

PHP_FUNCTION(bench_cpp_array_build)
{
	zend_long n;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_LONG(n)
	ZEND_PARSE_PARAMETERS_END();

	if (n < 0 || n > max_build) {
		zend_argument_value_error(1, "must be between 0 and 16777216");
		RETURN_THROWS();
	}

	array_init_size(return_value, static_cast<uint32_t>(n));
	zend_hash_real_init_packed(Z_ARRVAL_P(return_value));
	ZEND_HASH_FILL_PACKED(Z_ARRVAL_P(return_value)) {
		for (zend_long i = 0; i < n; i++) {
			ZEND_HASH_FILL_SET_LONG(i);
			ZEND_HASH_FILL_NEXT();
		}
	} ZEND_HASH_FILL_END();
}

PHP_FUNCTION(bench_cpp_hash_lookup)
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

PHP_FUNCTION(bench_cpp_array_identity)
{
	zval *arr;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_ARRAY(arr)
	ZEND_PARSE_PARAMETERS_END();

	RETURN_COPY(arr);
}

PHP_FUNCTION(bench_cpp_throw)
{
	zend_long code;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_LONG(code)
	ZEND_PARSE_PARAMETERS_END();

	zend_throw_exception(zend_ce_exception, "boom", code);
	RETURN_THROWS();
}

PHP_FUNCTION(bench_cpp_split)
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
	const std::string_view input = view(s);
	const std::string_view separator = view(sep);
	size_t start = 0;
	for (size_t found; (found = input.find(separator, start)) != std::string_view::npos; start = found + separator.size()) {
		add_next_index_stringl(return_value, input.data() + start, found - start);
	}
	add_next_index_stringl(return_value, input.data() + start, input.size() - start);
}

PHP_FUNCTION(bench_cpp_counter)
{
	ZEND_PARSE_PARAMETERS_NONE();

	RETURN_LONG(++BENCH_CPP_G(counter));
}

PHP_FUNCTION(bench_cpp_invoke)
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

PHP_METHOD(BenchCppPoint, __construct)
{
	double x, y;

	ZEND_PARSE_PARAMETERS_START(2, 2)
		Z_PARAM_DOUBLE(x)
		Z_PARAM_DOUBLE(y)
	ZEND_PARSE_PARAMETERS_END();

	Point *point = Point::from(ZEND_THIS);
	point->x = x;
	point->y = y;
}

PHP_METHOD(BenchCppPoint, length)
{
	ZEND_PARSE_PARAMETERS_NONE();

	const Point *point = Point::from(ZEND_THIS);
	RETURN_DOUBLE(std::sqrt(point->x * point->x + point->y * point->y));
}

PHP_METHOD(BenchCppPoint, translate)
{
	double dx, dy;

	ZEND_PARSE_PARAMETERS_START(2, 2)
		Z_PARAM_DOUBLE(dx)
		Z_PARAM_DOUBLE(dy)
	ZEND_PARSE_PARAMETERS_END();

	Point *point = Point::from(ZEND_THIS);
	point->x += dx;
	point->y += dy;
}

PHP_MINIT_FUNCTION(bench_cpp)
{
	point_ce = register_class_BenchCppPoint();
	point_ce->create_object = point_create;
	memcpy(&point_handlers, &std_object_handlers, sizeof(zend_object_handlers));
	point_handlers.offset = offsetof(Point, std);
	point_handlers.clone_obj = nullptr;
	return SUCCESS;
}

PHP_GINIT_FUNCTION(bench_cpp)
{
#if defined(ZTS) && defined(COMPILE_DL_BENCH_CPP)
	ZEND_TSRMLS_CACHE_UPDATE();
#endif
	bench_cpp_globals->counter = 0;
}

PHP_RINIT_FUNCTION(bench_cpp)
{
#if defined(ZTS) && defined(COMPILE_DL_BENCH_CPP)
	ZEND_TSRMLS_CACHE_UPDATE();
#endif
	BENCH_CPP_G(counter) = 0;

	return SUCCESS;
}

PHP_MINFO_FUNCTION(bench_cpp)
{
	php_info_print_table_start();
	php_info_print_table_header(2, "bench_cpp support", "enabled");
	php_info_print_table_end();
}

zend_module_entry bench_cpp_module_entry = {
	STANDARD_MODULE_HEADER,
	"bench_cpp",
	ext_functions,
	PHP_MINIT(bench_cpp),
	nullptr,
	PHP_RINIT(bench_cpp),
	nullptr,
	PHP_MINFO(bench_cpp),
	PHP_BENCH_CPP_VERSION,
	PHP_MODULE_GLOBALS(bench_cpp),
	PHP_GINIT(bench_cpp),
	nullptr,
	nullptr,
	STANDARD_MODULE_PROPERTIES_EX
};

#ifdef COMPILE_DL_BENCH_CPP
# ifdef ZTS
ZEND_TSRMLS_CACHE_DEFINE()
# endif
ZEND_GET_MODULE(bench_cpp)
#endif
