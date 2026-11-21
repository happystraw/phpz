#include "phpx_ext.h"
#include "std/string.h"
#include "../zig/bench_zig_arginfo.h"

using namespace php;

PHPX_FUNCTION(bench_call)
{
    return nullptr;
}

PHPX_FUNCTION(bench_args)
{
    const auto optional = args[4];
    return args[0].toInt() ^ static_cast<Int>(String(args[1]).length())
        ^ (args[2].toFloat() > 0 ? 16 : 0) ^ (args[3].toBool() ? 32 : 0)
        ^ (optional.isNull() ? 64 : optional.toInt());
}

PHPX_FUNCTION(bench_sum)
{
    const Array values(args[0]);
    zend_ulong sum = 0;
    const auto end = values.end();
    for (auto item = values.begin(); item != end; ++item) {
        const zval *value = item.current();
        ZVAL_DEINDIRECT(value);
        value = unwrap_zval(value);
        if (Z_TYPE_P(value) == IS_LONG) {
            sum += static_cast<zend_ulong>(Z_LVAL_P(value));
        }
    }
    return static_cast<Int>(sum);
}

PHPX_FUNCTION(bench_build)
{
    const auto size = args[0].toInt();
    if (size < 0 || size > 65536) {
        return php::throwException(zend_ce_value_error, "size must be between 0 and 65536");
    }
    Array values(static_cast<size_t>(size));
    for (Int i = 0; i < size; i++) {
        values.append(i);
    }
    return values;
}

PHPX_FUNCTION(bench_invoke)
{
    return php::call(args[0], {args[1].toInt()});
}

PHPX_FUNCTION(bench_lookup)
{
    const Array values(args[0]);
    const auto value = values.get(String(args[1]));
    return value.isInt() ? value : Variant{};
}

PHPX_FUNCTION(bench_cow)
{
    Array values(args[0]);
    values.set(static_cast<zend_ulong>(0), args[1].toInt());
    return values;
}

PHPX_FUNCTION(bench_split)
{
    return String(args[0]).split(",");
}

PHPX_FUNCTION(bench_upper)
{
    return php::fn::strtoupper(String(args[0]));
}

PHPX_FUNCTION(bench_length)
{
    return static_cast<Int>(String(args[0]).length());
}

PHPX_METHOD(BenchPoint, read)
{
    return _this.get("value").toInt();
}

PHPX_EXTENSION()
{
    auto *extension = new php::Extension("bench_phpx", "0.1.0");
    extension->registerFunctions(ext_functions);
    extension->onStart = [extension] {
        auto *point = new php::Class("BenchPoint");
        point->registerFunctions(class_BenchPoint_methods);
        extension->registerClass(point);

        // Match the shared stub's class declaration. PHPX handles method dispatch.
        auto *entry = point->ptr();
        entry->ce_flags |= ZEND_ACC_FINAL;
        zval value;
        ZVAL_LONG(&value, 0);
        zend_declare_typed_property(entry, ZSTR_KNOWN(ZEND_STR_VALUE), &value,
            ZEND_ACC_PUBLIC, nullptr, (zend_type) ZEND_TYPE_INIT_MASK(MAY_BE_LONG));
    };
    return extension;
}
