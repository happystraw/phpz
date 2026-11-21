#include "php.h"
#include "php_bench_c.h"
#include "ext/standard/php_string.h"
#include "../zig/bench_zig_arginfo.h"

static zend_class_entry *point_class;

PHP_FUNCTION(bench_call)
{
    ZEND_PARSE_PARAMETERS_NONE();
}

PHP_FUNCTION(bench_args)
{
    zend_long number, optional = 0;
    zend_string *text;
    double decimal;
    bool flag, optional_is_null = true;

    ZEND_PARSE_PARAMETERS_START(4, 5)
        Z_PARAM_LONG(number)
        Z_PARAM_STR(text)
        Z_PARAM_DOUBLE(decimal)
        Z_PARAM_BOOL(flag)
        Z_PARAM_OPTIONAL
        Z_PARAM_LONG_OR_NULL(optional, optional_is_null)
    ZEND_PARSE_PARAMETERS_END();

    RETURN_LONG(number ^ (zend_long) ZSTR_LEN(text) ^ (decimal > 0 ? 16 : 0)
        ^ (flag ? 32 : 0) ^ (optional_is_null ? 64 : optional));
}

PHP_FUNCTION(bench_sum)
{
    HashTable *values;
    ZEND_PARSE_PARAMETERS_START(1, 1)
        Z_PARAM_ARRAY_HT(values)
    ZEND_PARSE_PARAMETERS_END();

    zend_ulong sum = 0;
    zval *value;
    ZEND_HASH_FOREACH_VAL(values, value) {
        if (Z_TYPE_P(value) == IS_LONG) {
            sum += (zend_ulong) Z_LVAL_P(value);
        } else if (UNEXPECTED(Z_TYPE_P(value) == IS_REFERENCE)) {
            zval *referent = Z_REFVAL_P(value);
            if (Z_TYPE_P(referent) == IS_LONG) {
                sum += (zend_ulong) Z_LVAL_P(referent);
            }
        }
    } ZEND_HASH_FOREACH_END();
    RETURN_LONG((zend_long) sum);
}

PHP_FUNCTION(bench_build)
{
    zend_long size;
    ZEND_PARSE_PARAMETERS_START(1, 1)
        Z_PARAM_LONG(size)
    ZEND_PARSE_PARAMETERS_END();

    if (size < 0 || size > 65536) {
        zend_argument_value_error(1, "must be between 0 and 65536");
        RETURN_THROWS();
    }
    array_init_size(return_value, size);
    if (size == 0) {
        return;
    }
    HashTable *values = Z_ARRVAL_P(return_value);
    zend_hash_real_init_packed(values);
    ZEND_HASH_FILL_PACKED(values) {
        for (zend_long i = 0; i < size; i++) {
            ZEND_HASH_FILL_SET_LONG(i);
            ZEND_HASH_FILL_NEXT();
        }
    } ZEND_HASH_FILL_END();
}

PHP_FUNCTION(bench_invoke)
{
    zend_fcall_info call;
    zend_fcall_info_cache cache;
    zend_long value;
    ZEND_PARSE_PARAMETERS_START(2, 2)
        Z_PARAM_FUNC(call, cache)
        Z_PARAM_LONG(value)
    ZEND_PARSE_PARAMETERS_END();

    zval argument;
    ZVAL_LONG(&argument, value);
    call.retval = return_value;
    call.params = &argument;
    call.param_count = 1;
    if (UNEXPECTED(zend_call_function(&call, &cache) == FAILURE)) {
        zend_throw_error(NULL, "Could not invoke benchmark callback");
        RETURN_THROWS();
    }
}

PHP_FUNCTION(bench_lookup)
{
    HashTable *values;
    zend_string *key;
    ZEND_PARSE_PARAMETERS_START(2, 2)
        Z_PARAM_ARRAY_HT(values)
        Z_PARAM_STR(key)
    ZEND_PARSE_PARAMETERS_END();

    zval *value = zend_symtable_find(values, key);
    if (value != NULL) {
        ZVAL_DEREF(value);
        if (Z_TYPE_P(value) == IS_LONG) {
            RETURN_LONG(Z_LVAL_P(value));
        }
    }
    RETURN_NULL();
}

PHP_FUNCTION(bench_cow)
{
    HashTable *values;
    zend_long replacement;
    ZEND_PARSE_PARAMETERS_START(2, 2)
        Z_PARAM_ARRAY_HT(values)
        Z_PARAM_LONG(replacement)
    ZEND_PARSE_PARAMETERS_END();

    HashTable *copy = zend_array_dup(values);
    zval value;
    ZVAL_LONG(&value, replacement);
    zend_hash_index_update(copy, 0, &value);
    RETURN_ARR(copy);
}

PHP_FUNCTION(bench_split)
{
    zend_string *record;
    ZEND_PARSE_PARAMETERS_START(1, 1)
        Z_PARAM_STR(record)
    ZEND_PARSE_PARAMETERS_END();

    array_init(return_value);
    php_explode(ZSTR_CHAR(','), record, return_value, ZEND_LONG_MAX);
}

PHP_FUNCTION(bench_upper)
{
    zend_string *text;
    ZEND_PARSE_PARAMETERS_START(1, 1)
        Z_PARAM_STR(text)
    ZEND_PARSE_PARAMETERS_END();
    RETURN_STR(zend_string_toupper(text));
}

PHP_FUNCTION(bench_length)
{
    zend_string *text;
    ZEND_PARSE_PARAMETERS_START(1, 1)
        Z_PARAM_STR(text)
    ZEND_PARSE_PARAMETERS_END();
    RETURN_LONG(ZSTR_LEN(text));
}

PHP_METHOD(BenchPoint, read)
{
    ZEND_PARSE_PARAMETERS_NONE();
    zval scratch;
    zval *value = zend_read_property(point_class, Z_OBJ_P(ZEND_THIS), "value", sizeof("value") - 1, false, &scratch);
    if (UNEXPECTED(EG(exception))) {
        RETURN_THROWS();
    }
    ZVAL_DEREF(value);
    RETURN_LONG(Z_LVAL_P(value));
}

static PHP_MINIT_FUNCTION(bench_c)
{
    point_class = register_class_BenchPoint();
    return SUCCESS;
}

#if defined(ZTS) && defined(COMPILE_DL_BENCH_C)
ZEND_TSRMLS_CACHE_DEFINE()

static PHP_RINIT_FUNCTION(bench_c)
{
    ZEND_TSRMLS_CACHE_UPDATE();
    return SUCCESS;
}
#endif

zend_module_entry bench_c_module_entry = {
    STANDARD_MODULE_HEADER,
    "bench_c",
    ext_functions,
    PHP_MINIT(bench_c),
    NULL,
#if defined(ZTS) && defined(COMPILE_DL_BENCH_C)
    PHP_RINIT(bench_c),
#else
    NULL,
#endif
    NULL, NULL,
    PHP_BENCH_C_VERSION,
    STANDARD_MODULE_PROPERTIES
};

#ifdef COMPILE_DL_BENCH_C
ZEND_GET_MODULE(bench_c)
#endif
