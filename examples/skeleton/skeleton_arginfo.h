/* This is a generated file, edit the .stub.php file instead.
 * Stub hash: d22e894300526c4a17a44dc8302dcfe201cf73d0 */

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_hello, 0, 0, IS_VOID, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_greet, 0, 1, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_Counter___construct, 0, 0, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, n, IS_LONG, 0, "0")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_Counter_add, 0, 1, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(0, n, IS_LONG, 0)
ZEND_END_ARG_INFO()

#define arginfo_class_Counter_dec arginfo_class_Counter_add

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_Counter_value, 0, 0, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_FUNCTION(hello);
ZEND_FUNCTION(greet);
ZEND_METHOD(Counter, __construct);
ZEND_METHOD(Counter, add);
ZEND_METHOD(Counter, dec);
ZEND_METHOD(Counter, value);

static const zend_function_entry ext_functions[] = {
	ZEND_FE(hello, arginfo_hello)
	ZEND_FE(greet, arginfo_greet)
	ZEND_FE_END
};

static const zend_function_entry class_Counter_methods[] = {
	ZEND_ME(Counter, __construct, arginfo_class_Counter___construct, ZEND_ACC_PUBLIC)
	ZEND_ME(Counter, add, arginfo_class_Counter_add, ZEND_ACC_PUBLIC)
	ZEND_ME(Counter, dec, arginfo_class_Counter_dec, ZEND_ACC_PUBLIC)
	ZEND_ME(Counter, value, arginfo_class_Counter_value, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};

static zend_class_entry *register_class_Counter(void)
{
	zend_class_entry ce, *class_entry;

	INIT_CLASS_ENTRY(ce, "Counter", class_Counter_methods);
#if (PHP_VERSION_ID >= 80400)
	class_entry = zend_register_internal_class_with_flags(&ce, NULL, 0);
#else
	class_entry = zend_register_internal_class_ex(&ce, NULL);
#endif

	return class_entry;
}
