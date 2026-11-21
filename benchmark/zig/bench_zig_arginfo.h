/* This is a generated file, edit bench_zig.stub.php instead.
 * Stub hash: 49e3cf4ca243bf26959277e33b4e1ec70069634f */

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_call, 0, 0, IS_VOID, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_args, 0, 4, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO(0, number, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO(0, text, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, decimal, IS_DOUBLE, 0)
	ZEND_ARG_TYPE_INFO(0, flag, _IS_BOOL, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, optional, IS_LONG, 1, "null")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_sum, 0, 1, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO(0, values, IS_ARRAY, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_build, 0, 1, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, size, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_invoke, 0, 2, IS_MIXED, 0)
	ZEND_ARG_TYPE_INFO(0, callback, IS_CALLABLE, 0)
	ZEND_ARG_TYPE_INFO(0, value, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_lookup, 0, 2, IS_LONG, 1)
	ZEND_ARG_TYPE_INFO(0, values, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, key, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_cow, 0, 2, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, values, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, replacement, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_split, 0, 1, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, record, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_upper, 0, 1, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, text, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_bench_length, 0, 1, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO(0, text, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_BenchPoint_read, 0, 0, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_FUNCTION(bench_call);
ZEND_FUNCTION(bench_args);
ZEND_FUNCTION(bench_sum);
ZEND_FUNCTION(bench_build);
ZEND_FUNCTION(bench_invoke);
ZEND_FUNCTION(bench_lookup);
ZEND_FUNCTION(bench_cow);
ZEND_FUNCTION(bench_split);
ZEND_FUNCTION(bench_upper);
ZEND_FUNCTION(bench_length);
ZEND_METHOD(BenchPoint, read);

static const zend_function_entry ext_functions[] = {
	ZEND_FE(bench_call, arginfo_bench_call)
	ZEND_FE(bench_args, arginfo_bench_args)
	ZEND_FE(bench_sum, arginfo_bench_sum)
	ZEND_FE(bench_build, arginfo_bench_build)
	ZEND_FE(bench_invoke, arginfo_bench_invoke)
	ZEND_FE(bench_lookup, arginfo_bench_lookup)
	ZEND_FE(bench_cow, arginfo_bench_cow)
	ZEND_FE(bench_split, arginfo_bench_split)
	ZEND_FE(bench_upper, arginfo_bench_upper)
	ZEND_FE(bench_length, arginfo_bench_length)
	ZEND_FE_END
};

static const zend_function_entry class_BenchPoint_methods[] = {
	ZEND_ME(BenchPoint, read, arginfo_class_BenchPoint_read, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};

static zend_class_entry *register_class_BenchPoint(void)
{
	zend_class_entry ce, *class_entry;

	INIT_CLASS_ENTRY(ce, "BenchPoint", class_BenchPoint_methods);
	class_entry = zend_register_internal_class_with_flags(&ce, NULL, ZEND_ACC_FINAL);

	zval property_value_default_value;
	ZVAL_LONG(&property_value_default_value, 0);
	zend_declare_typed_property(class_entry, ZSTR_KNOWN(ZEND_STR_VALUE), &property_value_default_value, ZEND_ACC_PUBLIC, NULL, (zend_type) ZEND_TYPE_INIT_MASK(MAY_BE_LONG));

	return class_entry;
}
