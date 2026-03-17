/* This is a generated file, edit the .stub.php file instead.
 * Stub hash: 7abe02f11e67201228eb7762577a7df6fbfde9da */

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_Pjs_Context___construct, 0, 0, 1)
	ZEND_ARG_OBJ_INFO(0, runtime, Pjs\\Runtime, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_OBJ_INFO_EX(arginfo_class_Pjs_Context_eval, 0, 1, Pjs\\Value, 0)
	ZEND_ARG_TYPE_INFO(0, code, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_Pjs_Value___construct, 0, 0, 1)
	ZEND_ARG_OBJ_INFO(0, context, Pjs\\Context, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, value, IS_MIXED, 0, "null")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_Pjs_Value___toString, 0, 0, IS_STRING, 0)
ZEND_END_ARG_INFO()


ZEND_METHOD(Pjs_Context, __construct);
ZEND_METHOD(Pjs_Context, eval);
ZEND_METHOD(Pjs_Value, __construct);
ZEND_METHOD(Pjs_Value, __toString);


static const zend_function_entry class_Pjs_Runtime_methods[] = {
	ZEND_FE_END
};


static const zend_function_entry class_Pjs_Context_methods[] = {
	ZEND_ME(Pjs_Context, __construct, arginfo_class_Pjs_Context___construct, ZEND_ACC_PUBLIC)
	ZEND_ME(Pjs_Context, eval, arginfo_class_Pjs_Context_eval, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};


static const zend_function_entry class_Pjs_Value_methods[] = {
	ZEND_ME(Pjs_Value, __construct, arginfo_class_Pjs_Value___construct, ZEND_ACC_PUBLIC)
	ZEND_ME(Pjs_Value, __toString, arginfo_class_Pjs_Value___toString, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};


static const zend_function_entry class_Pjs_Exception_methods[] = {
	ZEND_FE_END
};

static zend_class_entry *register_class_Pjs_Runtime(void)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "Pjs", "Runtime", class_Pjs_Runtime_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_FINAL;

	return class_entry;
}

static zend_class_entry *register_class_Pjs_Context(void)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "Pjs", "Context", class_Pjs_Context_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_FINAL;

	return class_entry;
}

static zend_class_entry *register_class_Pjs_Value(zend_class_entry *class_entry_Stringable)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "Pjs", "Value", class_Pjs_Value_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_FINAL;
	zend_class_implements(class_entry, 1, class_entry_Stringable);

	zval property_value_default_value;
	ZVAL_UNDEF(&property_value_default_value);
	zend_string *property_value_name = zend_string_init("value", sizeof("value") - 1, 1);
	zend_declare_typed_property(class_entry, property_value_name, &property_value_default_value, ZEND_ACC_PUBLIC|ZEND_ACC_READONLY, NULL, (zend_type) ZEND_TYPE_INIT_MASK(MAY_BE_ANY));
	zend_string_release(property_value_name);

	return class_entry;
}

static zend_class_entry *register_class_Pjs_Exception(zend_class_entry *class_entry_RuntimeException)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "Pjs", "Exception", class_Pjs_Exception_methods);
	class_entry = zend_register_internal_class_ex(&ce, class_entry_RuntimeException);
	class_entry->ce_flags |= ZEND_ACC_FINAL;

	return class_entry;
}
