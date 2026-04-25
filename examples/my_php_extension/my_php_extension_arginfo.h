/* This is a generated file, edit the .stub.php file instead.
 * Stub hash: 14b4a440956780f01788b1c29547a425e2e2c74e */

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_hello, 0, 0, IS_VOID, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_greet, 0, 1, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_OBJ_INFO_EX(arginfo_human, 0, 1, MyPHPExt\\Human, 0)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, age, IS_LONG, 1, "NULL")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_MyPHPExt_Counter___construct, 0, 0, 1)
	ZEND_ARG_TYPE_INFO(0, n, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Counter_add, 0, 1, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(0, n, IS_LONG, 0)
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_Counter_dec arginfo_class_MyPHPExt_Counter_add

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Counter_value, 0, 0, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_MyPHPExt_Human___construct, 0, 0, 1)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, age, IS_LONG, 1, "NULL")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Human_setName, 0, 1, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Human_getName, 0, 0, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Human_setAge, 0, 1, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(0, age, IS_LONG, 1)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Human_getAge, 0, 0, IS_LONG, 1)
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_Human___toString arginfo_class_MyPHPExt_Human_getName

#define arginfo_class_MyPHPExt_Human_species arginfo_class_MyPHPExt_Human_getName


ZEND_FUNCTION(hello);
ZEND_FUNCTION(greet);
ZEND_FUNCTION(human);
ZEND_METHOD(MyPHPExt_Counter, __construct);
ZEND_METHOD(MyPHPExt_Counter, add);
ZEND_METHOD(MyPHPExt_Counter, dec);
ZEND_METHOD(MyPHPExt_Counter, value);
ZEND_METHOD(MyPHPExt_Human, __construct);
ZEND_METHOD(MyPHPExt_Human, setName);
ZEND_METHOD(MyPHPExt_Human, getName);
ZEND_METHOD(MyPHPExt_Human, setAge);
ZEND_METHOD(MyPHPExt_Human, getAge);
ZEND_METHOD(MyPHPExt_Human, __toString);
ZEND_METHOD(MyPHPExt_Human, species);


static const zend_function_entry ext_functions[] = {
	ZEND_FE(hello, arginfo_hello)
	ZEND_FE(greet, arginfo_greet)
	ZEND_FE(human, arginfo_human)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_Counter_methods[] = {
	ZEND_ME(MyPHPExt_Counter, __construct, arginfo_class_MyPHPExt_Counter___construct, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Counter, add, arginfo_class_MyPHPExt_Counter_add, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Counter, dec, arginfo_class_MyPHPExt_Counter_dec, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Counter, value, arginfo_class_MyPHPExt_Counter_value, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_Human_methods[] = {
	ZEND_ME(MyPHPExt_Human, __construct, arginfo_class_MyPHPExt_Human___construct, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Human, setName, arginfo_class_MyPHPExt_Human_setName, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Human, getName, arginfo_class_MyPHPExt_Human_getName, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Human, setAge, arginfo_class_MyPHPExt_Human_setAge, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Human, getAge, arginfo_class_MyPHPExt_Human_getAge, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Human, __toString, arginfo_class_MyPHPExt_Human___toString, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Human, species, arginfo_class_MyPHPExt_Human_species, ZEND_ACC_PUBLIC|ZEND_ACC_STATIC)
	ZEND_FE_END
};

static zend_class_entry *register_class_MyPHPExt_Counter(void)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "Counter", class_MyPHPExt_Counter_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_FINAL;

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_Human(zend_class_entry *class_entry_Stringable)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "Human", class_MyPHPExt_Human_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_FINAL;
	zend_class_implements(class_entry, 1, class_entry_Stringable);

	return class_entry;
}
