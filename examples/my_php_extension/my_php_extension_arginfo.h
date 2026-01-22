/* This is a generated file, edit the .stub.php file instead.
 * Stub hash: cf4b3cda99d33eef53ff022b3b0056042ac00bab */

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_hello_world, 0, 0, IS_VOID, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_whoami, 0, 1, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
	ZEND_ARG_TYPE_MASK(0, age, MAY_BE_LONG|MAY_BE_STRING|MAY_BE_NULL, "NULL")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_MyPHPExt_Human___construct, 0, 0, 2)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, age, IS_LONG, 1)
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

#define arginfo_class_MyPHPExt_Human_version arginfo_hello_world


ZEND_FUNCTION(hello_world);
ZEND_FUNCTION(whoami);
ZEND_METHOD(MyPHPExt_Human, __construct);
ZEND_METHOD(MyPHPExt_Human, setName);
ZEND_METHOD(MyPHPExt_Human, getName);
ZEND_METHOD(MyPHPExt_Human, setAge);
ZEND_METHOD(MyPHPExt_Human, getAge);
ZEND_METHOD(MyPHPExt_Human, __toString);
ZEND_METHOD(MyPHPExt_Human, version);


static const zend_function_entry ext_functions[] = {
	ZEND_FE(hello_world, arginfo_hello_world)
	ZEND_FE(whoami, arginfo_whoami)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_Human_methods[] = {
	ZEND_ME(MyPHPExt_Human, __construct, arginfo_class_MyPHPExt_Human___construct, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Human, setName, arginfo_class_MyPHPExt_Human_setName, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Human, getName, arginfo_class_MyPHPExt_Human_getName, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Human, setAge, arginfo_class_MyPHPExt_Human_setAge, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Human, getAge, arginfo_class_MyPHPExt_Human_getAge, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Human, __toString, arginfo_class_MyPHPExt_Human___toString, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Human, version, arginfo_class_MyPHPExt_Human_version, ZEND_ACC_PUBLIC|ZEND_ACC_STATIC)
	ZEND_FE_END
};

static zend_class_entry *register_class_MyPHPExt_Human(zend_class_entry *class_entry_Stringable)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "Human", class_MyPHPExt_Human_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_FINAL;
	zend_class_implements(class_entry, 1, class_entry_Stringable);

	return class_entry;
}
