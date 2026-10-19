/* This is a generated file, edit the .stub.php file instead.
 * Stub hash: 400cb02ff6d6240dd26d8ce0fd2036aad010ec9e */

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_empty, 0, 0, IS_VOID, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_parse_multi, 0, 7, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(0, n, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO(0, s, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, d, IS_DOUBLE, 0)
	ZEND_ARG_TYPE_INFO(0, b, _IS_BOOL, 0)
	ZEND_ARG_TYPE_INFO(0, arr, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, obj, IS_OBJECT, 0)
	ZEND_ARG_TYPE_INFO(0, v, IS_MIXED, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, opt, IS_LONG, 1, "null")
ZEND_END_ARG_INFO()

#define arginfo_bench_zig_parse_multi_pp arginfo_bench_zig_parse_multi

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_array_sum_fast, 0, 1, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO(0, arr, IS_ARRAY, 0)
ZEND_END_ARG_INFO()

#define arginfo_bench_zig_array_sum_parse arginfo_bench_zig_array_sum_fast

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_add, 0, 2, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO(0, a, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO(0, b, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_muladd, 0, 3, IS_DOUBLE, 0)
	ZEND_ARG_TYPE_INFO(0, a, IS_DOUBLE, 0)
	ZEND_ARG_TYPE_INFO(0, b, IS_DOUBLE, 0)
	ZEND_ARG_TYPE_INFO(0, c, IS_DOUBLE, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_str_len, 0, 1, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO(0, s, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_int_to_string, 0, 1, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, n, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_str_upper, 0, 1, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, s, IS_STRING, 0)
ZEND_END_ARG_INFO()

#define arginfo_bench_zig_array_sum_assoc arginfo_bench_zig_array_sum_fast

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_array_build, 0, 1, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, n, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_hash_lookup, 0, 2, IS_MIXED, 0)
	ZEND_ARG_TYPE_INFO(0, arr, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, key, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_array_identity, 0, 1, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, arr, IS_ARRAY, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_throw, 0, 1, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(0, code, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_split, 0, 2, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, s, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, separator, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_counter, 0, 0, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_zig_invoke, 0, 2, IS_MIXED, 0)
	ZEND_ARG_TYPE_INFO(0, callback, IS_CALLABLE, 0)
	ZEND_ARG_TYPE_INFO(0, arg, IS_MIXED, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_BenchZigPoint___construct, 0, 0, 2)
	ZEND_ARG_TYPE_INFO(0, x, IS_DOUBLE, 0)
	ZEND_ARG_TYPE_INFO(0, y, IS_DOUBLE, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_BenchZigPoint_length, 0, 0, IS_DOUBLE, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_BenchZigPoint_translate, 0, 2, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(0, dx, IS_DOUBLE, 0)
	ZEND_ARG_TYPE_INFO(0, dy, IS_DOUBLE, 0)
ZEND_END_ARG_INFO()

ZEND_FUNCTION(bench_zig_empty);
ZEND_FUNCTION(bench_zig_parse_multi);
ZEND_FUNCTION(bench_zig_parse_multi_pp);
ZEND_FUNCTION(bench_zig_array_sum_fast);
ZEND_FUNCTION(bench_zig_array_sum_parse);
ZEND_FUNCTION(bench_zig_add);
ZEND_FUNCTION(bench_zig_muladd);
ZEND_FUNCTION(bench_zig_str_len);
ZEND_FUNCTION(bench_zig_int_to_string);
ZEND_FUNCTION(bench_zig_str_upper);
ZEND_FUNCTION(bench_zig_array_sum_assoc);
ZEND_FUNCTION(bench_zig_array_build);
ZEND_FUNCTION(bench_zig_hash_lookup);
ZEND_FUNCTION(bench_zig_array_identity);
ZEND_FUNCTION(bench_zig_throw);
ZEND_FUNCTION(bench_zig_split);
ZEND_FUNCTION(bench_zig_counter);
ZEND_FUNCTION(bench_zig_invoke);
ZEND_METHOD(BenchZigPoint, __construct);
ZEND_METHOD(BenchZigPoint, length);
ZEND_METHOD(BenchZigPoint, translate);

static const zend_function_entry ext_functions[] = {
	ZEND_FE(bench_zig_empty, arginfo_bench_zig_empty)
	ZEND_FE(bench_zig_parse_multi, arginfo_bench_zig_parse_multi)
	ZEND_FE(bench_zig_parse_multi_pp, arginfo_bench_zig_parse_multi_pp)
	ZEND_FE(bench_zig_array_sum_fast, arginfo_bench_zig_array_sum_fast)
	ZEND_FE(bench_zig_array_sum_parse, arginfo_bench_zig_array_sum_parse)
	ZEND_FE(bench_zig_add, arginfo_bench_zig_add)
	ZEND_FE(bench_zig_muladd, arginfo_bench_zig_muladd)
	ZEND_FE(bench_zig_str_len, arginfo_bench_zig_str_len)
	ZEND_FE(bench_zig_int_to_string, arginfo_bench_zig_int_to_string)
	ZEND_FE(bench_zig_str_upper, arginfo_bench_zig_str_upper)
	ZEND_FE(bench_zig_array_sum_assoc, arginfo_bench_zig_array_sum_assoc)
	ZEND_FE(bench_zig_array_build, arginfo_bench_zig_array_build)
	ZEND_FE(bench_zig_hash_lookup, arginfo_bench_zig_hash_lookup)
	ZEND_FE(bench_zig_array_identity, arginfo_bench_zig_array_identity)
	ZEND_FE(bench_zig_throw, arginfo_bench_zig_throw)
	ZEND_FE(bench_zig_split, arginfo_bench_zig_split)
	ZEND_FE(bench_zig_counter, arginfo_bench_zig_counter)
	ZEND_FE(bench_zig_invoke, arginfo_bench_zig_invoke)
	ZEND_FE_END
};

static const zend_function_entry class_BenchZigPoint_methods[] = {
	ZEND_ME(BenchZigPoint, __construct, arginfo_class_BenchZigPoint___construct, ZEND_ACC_PUBLIC)
	ZEND_ME(BenchZigPoint, length, arginfo_class_BenchZigPoint_length, ZEND_ACC_PUBLIC)
	ZEND_ME(BenchZigPoint, translate, arginfo_class_BenchZigPoint_translate, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};

static zend_class_entry *register_class_BenchZigPoint(void)
{
	zend_class_entry ce, *class_entry;

	INIT_CLASS_ENTRY(ce, "BenchZigPoint", class_BenchZigPoint_methods);
	class_entry = zend_register_internal_class_with_flags(&ce, NULL, ZEND_ACC_FINAL);

	return class_entry;
}
