/* This is a generated file, edit the .stub.php file instead.
 * Stub hash: ffa7b377cfeef376b15c426b240ca9756695390d */

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


ZEND_FUNCTION(bench_zig_empty);
ZEND_FUNCTION(bench_zig_parse_multi);
ZEND_FUNCTION(bench_zig_parse_multi_pp);
ZEND_FUNCTION(bench_zig_array_sum_fast);
ZEND_FUNCTION(bench_zig_array_sum_parse);


static const zend_function_entry ext_functions[] = {
	ZEND_FE(bench_zig_empty, arginfo_bench_zig_empty)
	ZEND_FE(bench_zig_parse_multi, arginfo_bench_zig_parse_multi)
	ZEND_FE(bench_zig_parse_multi_pp, arginfo_bench_zig_parse_multi_pp)
	ZEND_FE(bench_zig_array_sum_fast, arginfo_bench_zig_array_sum_fast)
	ZEND_FE(bench_zig_array_sum_parse, arginfo_bench_zig_array_sum_parse)
	ZEND_FE_END
};
