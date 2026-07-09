/* This is a generated file, edit the .stub.php file instead.
 * Stub hash: 34215a54f14dd37a56a161859166f9ee56368b8d */

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_hello, 0, 0, IS_VOID, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_greet, 0, 1, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_iniGetGreeting, 0, 0, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_iniGetMaxUsers, 0, 0, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_iniGetDebug, 0, 0, _IS_BOOL, 0)
ZEND_END_ARG_INFO()

#define arginfo_iniGetMode arginfo_iniGetGreeting

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_MyPHPExt_increment, 0, 1, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(1, value, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_OBJ_INFO_EX(arginfo_MyPHPExt_findById, 0, 1, MyPHPExt\\\125ser, 1)
	ZEND_ARG_TYPE_MASK(0, id, MAY_BE_STRING|MAY_BE_LONG, NULL)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_OBJ_INFO_EX(arginfo_MyPHPExt_getDefaultUser, 0, 0, MyPHPExt\\\125ser, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_MyPHPExt_listStatuses, 0, 0, IS_ARRAY, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_MyPHPExt_map, 0, 2, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, arr, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, cb, IS_CALLABLE, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_MyPHPExt_testExpectArgScalars, 0, 3, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, str, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, int, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO(0, float, IS_DOUBLE, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, flag, _IS_BOOL, 0, "true")
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, nullable_str, IS_STRING, 1, "null")
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, opt_int, IS_LONG, 0, "0")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_MyPHPExt_testExpectArgArrayObject, 0, 2, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, data, IS_ARRAY, 0)
	ZEND_ARG_OBJ_INFO(0, user, MyPHPExt\\\125ser, 0)
	ZEND_ARG_OBJ_INFO_WITH_DEFAULT_VALUE(0, nullable_user, MyPHPExt\\\125ser, 1, "null")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_MyPHPExt_testExpectArgMixed, 0, 1, IS_MIXED, 0)
	ZEND_ARG_TYPE_INFO(0, value, IS_MIXED, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_MyPHPExt_inspectObjectProperty, 0, 2, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, obj, IS_OBJECT, 0)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, silent, _IS_BOOL, 0, "false")
ZEND_END_ARG_INFO()

#define arginfo_MyPHPExt_tryCreateInvalidUser arginfo_hello

#define arginfo_MyPHPExt_testHeapAllocatorBailout arginfo_MyPHPExt_listStatuses

#define arginfo_class_MyPHPExt_Identifiable_getId arginfo_iniGetMaxUsers

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_MyPHPExt_ExampleAttribute___construct, 0, 0, 1)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, note, IS_STRING, 1, "null")
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_AbstractEntity_onLoad arginfo_hello

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_AbstractEntity_handle, 0, 1, IS_VOID, 0)
	ZEND_ARG_TYPE_MASK(0, id, MAY_BE_STRING|MAY_BE_LONG, NULL)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_MyPHPExt_User___construct, 0, 0, 1)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, age, IS_LONG, 1, "null")
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_User_getId arginfo_iniGetMaxUsers

#define arginfo_class_MyPHPExt_User_handle arginfo_class_MyPHPExt_AbstractEntity_handle

#define arginfo_class_MyPHPExt_User___toString arginfo_iniGetGreeting

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Dumper_dump, 0, 0, IS_VOID, 0)
	ZEND_ARG_VARIADIC_TYPE_INFO(0, value, IS_MIXED, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_MyPHPExt_Counter___construct, 0, 0, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, n, IS_LONG, 0, "0")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Counter_add, 0, 1, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(0, n, IS_LONG, 0)
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_Counter_dec arginfo_class_MyPHPExt_Counter_add

#define arginfo_class_MyPHPExt_Counter_value arginfo_iniGetMaxUsers

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_MyPHPExt_ArrayLike___construct, 0, 0, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, data, IS_ARRAY, 0, "[]")
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_ArrayLike_toArray arginfo_MyPHPExt_listStatuses

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_ArrayLike_offsetExists, 0, 1, _IS_BOOL, 0)
	ZEND_ARG_TYPE_INFO(0, offset, IS_MIXED, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_ArrayLike_offsetGet, 0, 1, IS_MIXED, 0)
	ZEND_ARG_TYPE_INFO(0, offset, IS_MIXED, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_ArrayLike_offsetSet, 0, 2, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(0, offset, IS_MIXED, 0)
	ZEND_ARG_TYPE_INFO(0, value, IS_MIXED, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_ArrayLike_offsetUnset, 0, 1, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(0, offset, IS_MIXED, 0)
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_ArrayLike_count arginfo_iniGetMaxUsers

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_ArrayLike_current, 0, 0, IS_MIXED, 0)
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_ArrayLike_key arginfo_class_MyPHPExt_ArrayLike_current

#define arginfo_class_MyPHPExt_ArrayLike_next arginfo_hello

#define arginfo_class_MyPHPExt_ArrayLike_rewind arginfo_hello

#define arginfo_class_MyPHPExt_ArrayLike_valid arginfo_iniGetDebug


ZEND_FUNCTION(hello);
ZEND_FUNCTION(greet);
ZEND_FUNCTION(iniGetGreeting);
ZEND_FUNCTION(iniGetMaxUsers);
ZEND_FUNCTION(iniGetDebug);
ZEND_FUNCTION(iniGetMode);
ZEND_FUNCTION(MyPHPExt_increment);
ZEND_FUNCTION(MyPHPExt_findById);
ZEND_FUNCTION(MyPHPExt_getDefaultUser);
ZEND_FUNCTION(MyPHPExt_listStatuses);
ZEND_FUNCTION(MyPHPExt_map);
ZEND_FUNCTION(MyPHPExt_testExpectArgScalars);
ZEND_FUNCTION(MyPHPExt_testExpectArgArrayObject);
ZEND_FUNCTION(MyPHPExt_testExpectArgMixed);
ZEND_FUNCTION(MyPHPExt_inspectObjectProperty);
ZEND_FUNCTION(MyPHPExt_tryCreateInvalidUser);
ZEND_FUNCTION(MyPHPExt_testHeapAllocatorBailout);
ZEND_METHOD(MyPHPExt_ExampleAttribute, __construct);
ZEND_METHOD(MyPHPExt_AbstractEntity, onLoad);
ZEND_METHOD(MyPHPExt_User, __construct);
ZEND_METHOD(MyPHPExt_User, getId);
ZEND_METHOD(MyPHPExt_User, handle);
ZEND_METHOD(MyPHPExt_User, __toString);
ZEND_METHOD(MyPHPExt_Dumper, dump);
ZEND_METHOD(MyPHPExt_Counter, __construct);
ZEND_METHOD(MyPHPExt_Counter, add);
ZEND_METHOD(MyPHPExt_Counter, dec);
ZEND_METHOD(MyPHPExt_Counter, value);
ZEND_METHOD(MyPHPExt_ArrayLike, __construct);
ZEND_METHOD(MyPHPExt_ArrayLike, toArray);
ZEND_METHOD(MyPHPExt_ArrayLike, offsetExists);
ZEND_METHOD(MyPHPExt_ArrayLike, offsetGet);
ZEND_METHOD(MyPHPExt_ArrayLike, offsetSet);
ZEND_METHOD(MyPHPExt_ArrayLike, offsetUnset);
ZEND_METHOD(MyPHPExt_ArrayLike, count);
ZEND_METHOD(MyPHPExt_ArrayLike, current);
ZEND_METHOD(MyPHPExt_ArrayLike, key);
ZEND_METHOD(MyPHPExt_ArrayLike, next);
ZEND_METHOD(MyPHPExt_ArrayLike, rewind);
ZEND_METHOD(MyPHPExt_ArrayLike, valid);


static const zend_function_entry ext_functions[] = {
	ZEND_FE(hello, arginfo_hello)
	ZEND_FE(greet, arginfo_greet)
	ZEND_FE(iniGetGreeting, arginfo_iniGetGreeting)
	ZEND_FE(iniGetMaxUsers, arginfo_iniGetMaxUsers)
	ZEND_FE(iniGetDebug, arginfo_iniGetDebug)
	ZEND_FE(iniGetMode, arginfo_iniGetMode)
	ZEND_NS_FALIAS("MyPHPExt", increment, MyPHPExt_increment, arginfo_MyPHPExt_increment)
	ZEND_NS_FALIAS("MyPHPExt", findById, MyPHPExt_findById, arginfo_MyPHPExt_findById)
	ZEND_NS_FALIAS("MyPHPExt", getDefaultUser, MyPHPExt_getDefaultUser, arginfo_MyPHPExt_getDefaultUser)
	ZEND_NS_FALIAS("MyPHPExt", listStatuses, MyPHPExt_listStatuses, arginfo_MyPHPExt_listStatuses)
	ZEND_NS_FALIAS("MyPHPExt", map, MyPHPExt_map, arginfo_MyPHPExt_map)
	ZEND_NS_FALIAS("MyPHPExt", testExpectArgScalars, MyPHPExt_testExpectArgScalars, arginfo_MyPHPExt_testExpectArgScalars)
	ZEND_NS_FALIAS("MyPHPExt", testExpectArgArrayObject, MyPHPExt_testExpectArgArrayObject, arginfo_MyPHPExt_testExpectArgArrayObject)
	ZEND_NS_FALIAS("MyPHPExt", testExpectArgMixed, MyPHPExt_testExpectArgMixed, arginfo_MyPHPExt_testExpectArgMixed)
	ZEND_NS_FALIAS("MyPHPExt", inspectObjectProperty, MyPHPExt_inspectObjectProperty, arginfo_MyPHPExt_inspectObjectProperty)
	ZEND_NS_FALIAS("MyPHPExt", tryCreateInvalidUser, MyPHPExt_tryCreateInvalidUser, arginfo_MyPHPExt_tryCreateInvalidUser)
	ZEND_NS_FALIAS("MyPHPExt", testHeapAllocatorBailout, MyPHPExt_testHeapAllocatorBailout, arginfo_MyPHPExt_testHeapAllocatorBailout)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_Identifiable_methods[] = {
	ZEND_ABSTRACT_ME_WITH_FLAGS(MyPHPExt_Identifiable, getId, arginfo_class_MyPHPExt_Identifiable_getId, ZEND_ACC_PUBLIC|ZEND_ACC_ABSTRACT)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_Status_methods[] = {
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_Role_methods[] = {
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_MyError_methods[] = {
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_ExampleAttribute_methods[] = {
	ZEND_ME(MyPHPExt_ExampleAttribute, __construct, arginfo_class_MyPHPExt_ExampleAttribute___construct, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_AbstractEntity_methods[] = {
	ZEND_ME(MyPHPExt_AbstractEntity, onLoad, arginfo_class_MyPHPExt_AbstractEntity_onLoad, ZEND_ACC_PROTECTED)
	ZEND_ABSTRACT_ME_WITH_FLAGS(MyPHPExt_AbstractEntity, handle, arginfo_class_MyPHPExt_AbstractEntity_handle, ZEND_ACC_PUBLIC|ZEND_ACC_ABSTRACT)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_User_methods[] = {
	ZEND_ME(MyPHPExt_User, __construct, arginfo_class_MyPHPExt_User___construct, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_User, getId, arginfo_class_MyPHPExt_User_getId, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_User, handle, arginfo_class_MyPHPExt_User_handle, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_User, __toString, arginfo_class_MyPHPExt_User___toString, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_Dumper_methods[] = {
	ZEND_ME(MyPHPExt_Dumper, dump, arginfo_class_MyPHPExt_Dumper_dump, ZEND_ACC_PUBLIC|ZEND_ACC_STATIC)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_Counter_methods[] = {
	ZEND_ME(MyPHPExt_Counter, __construct, arginfo_class_MyPHPExt_Counter___construct, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Counter, add, arginfo_class_MyPHPExt_Counter_add, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Counter, dec, arginfo_class_MyPHPExt_Counter_dec, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Counter, value, arginfo_class_MyPHPExt_Counter_value, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_ArrayLike_methods[] = {
	ZEND_ME(MyPHPExt_ArrayLike, __construct, arginfo_class_MyPHPExt_ArrayLike___construct, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_ArrayLike, toArray, arginfo_class_MyPHPExt_ArrayLike_toArray, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_ArrayLike, offsetExists, arginfo_class_MyPHPExt_ArrayLike_offsetExists, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_ArrayLike, offsetGet, arginfo_class_MyPHPExt_ArrayLike_offsetGet, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_ArrayLike, offsetSet, arginfo_class_MyPHPExt_ArrayLike_offsetSet, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_ArrayLike, offsetUnset, arginfo_class_MyPHPExt_ArrayLike_offsetUnset, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_ArrayLike, count, arginfo_class_MyPHPExt_ArrayLike_count, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_ArrayLike, current, arginfo_class_MyPHPExt_ArrayLike_current, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_ArrayLike, key, arginfo_class_MyPHPExt_ArrayLike_key, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_ArrayLike, next, arginfo_class_MyPHPExt_ArrayLike_next, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_ArrayLike, rewind, arginfo_class_MyPHPExt_ArrayLike_rewind, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_ArrayLike, valid, arginfo_class_MyPHPExt_ArrayLike_valid, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};

static void register_my_php_extension_symbols(int module_number)
{
	REGISTER_STRING_CONSTANT("MY_EXT_VERSION", "1.0.0", CONST_PERSISTENT);
	REGISTER_LONG_CONSTANT("MyPHPExt\\VERSION", 1, CONST_PERSISTENT);
}

static zend_class_entry *register_class_MyPHPExt_Identifiable(void)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "Identifiable", class_MyPHPExt_Identifiable_methods);
	class_entry = zend_register_internal_interface(&ce);

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_Status(void)
{
	zend_class_entry *class_entry = zend_register_internal_enum("MyPHPExt\\Status", IS_LONG, class_MyPHPExt_Status_methods);

	zval enum_case_Active_value;
	ZVAL_LONG(&enum_case_Active_value, 1);
	zend_enum_add_case_cstr(class_entry, "Active", &enum_case_Active_value);

	zval enum_case_Inactive_value;
	ZVAL_LONG(&enum_case_Inactive_value, 0);
	zend_enum_add_case_cstr(class_entry, "Inactive", &enum_case_Inactive_value);

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_Role(void)
{
	zend_class_entry *class_entry = zend_register_internal_enum("MyPHPExt\\Role", IS_STRING, class_MyPHPExt_Role_methods);

	zval enum_case_Admin_value;
	zend_string *enum_case_Admin_value_str = zend_string_init("admin", strlen("admin"), 1);
	ZVAL_STR(&enum_case_Admin_value, enum_case_Admin_value_str);
	zend_enum_add_case_cstr(class_entry, "Admin", &enum_case_Admin_value);

	zval enum_case_User_value;
	zend_string *enum_case_User_value_str = zend_string_init("user", strlen("user"), 1);
	ZVAL_STR(&enum_case_User_value, enum_case_User_value_str);
	zend_enum_add_case_cstr(class_entry, "User", &enum_case_User_value);

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_MyError(zend_class_entry *class_entry_Exception)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "MyError", class_MyPHPExt_MyError_methods);
	class_entry = zend_register_internal_class_ex(&ce, class_entry_Exception);

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_ExampleAttribute(void)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "ExampleAttribute", class_MyPHPExt_ExampleAttribute_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_FINAL;

	zval property_name_default_value;
	ZVAL_UNDEF(&property_name_default_value);
	zend_string *property_name_name = zend_string_init("name", sizeof("name") - 1, 1);
	zend_declare_typed_property(class_entry, property_name_name, &property_name_default_value, ZEND_ACC_PUBLIC, NULL, (zend_type) ZEND_TYPE_INIT_MASK(MAY_BE_STRING));
	zend_string_release(property_name_name);

	zval property_note_default_value;
	ZVAL_NULL(&property_note_default_value);
	zend_string *property_note_name = zend_string_init("note", sizeof("note") - 1, 1);
	zend_declare_typed_property(class_entry, property_note_name, &property_note_default_value, ZEND_ACC_PUBLIC, NULL, (zend_type) ZEND_TYPE_INIT_MASK(MAY_BE_STRING|MAY_BE_NULL));
	zend_string_release(property_note_name);

	zend_string *attribute_name_Attribute_class_MyPHPExt_ExampleAttribute_0 = zend_string_init_interned("Attribute", sizeof("Attribute") - 1, 1);
	zend_attribute *attribute_Attribute_class_MyPHPExt_ExampleAttribute_0 = zend_add_class_attribute(class_entry, attribute_name_Attribute_class_MyPHPExt_ExampleAttribute_0, 1);
	zend_string_release(attribute_name_Attribute_class_MyPHPExt_ExampleAttribute_0);
	zval attribute_Attribute_class_MyPHPExt_ExampleAttribute_0_arg0;
	ZVAL_LONG(&attribute_Attribute_class_MyPHPExt_ExampleAttribute_0_arg0, ZEND_ATTRIBUTE_TARGET_CLASS | ZEND_ATTRIBUTE_TARGET_PARAMETER | ZEND_ATTRIBUTE_IS_REPEATABLE);
	ZVAL_COPY_VALUE(&attribute_Attribute_class_MyPHPExt_ExampleAttribute_0->args[0].value, &attribute_Attribute_class_MyPHPExt_ExampleAttribute_0_arg0);

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_AbstractEntity(zend_class_entry *class_entry_MyPHPExt_Identifiable)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "AbstractEntity", class_MyPHPExt_AbstractEntity_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_ABSTRACT;
	zend_class_implements(class_entry, 1, class_entry_MyPHPExt_Identifiable);

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_User(zend_class_entry *class_entry_MyPHPExt_AbstractEntity, zend_class_entry *class_entry_Stringable)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "User", class_MyPHPExt_User_methods);
	class_entry = zend_register_internal_class_ex(&ce, class_entry_MyPHPExt_AbstractEntity);
	class_entry->ce_flags |= ZEND_ACC_FINAL;
	zend_class_implements(class_entry, 1, class_entry_Stringable);

	zval const_MIN_AGE_value;
	ZVAL_LONG(&const_MIN_AGE_value, 0);
	zend_string *const_MIN_AGE_name = zend_string_init_interned("MIN_AGE", sizeof("MIN_AGE") - 1, 1);
	zend_declare_class_constant_ex(class_entry, const_MIN_AGE_name, &const_MIN_AGE_value, ZEND_ACC_PUBLIC, NULL);
	zend_string_release(const_MIN_AGE_name);

	zval property_name_default_value;
	ZVAL_UNDEF(&property_name_default_value);
	zend_string *property_name_name = zend_string_init("name", sizeof("name") - 1, 1);
	zend_declare_typed_property(class_entry, property_name_name, &property_name_default_value, ZEND_ACC_PUBLIC, NULL, (zend_type) ZEND_TYPE_INIT_MASK(MAY_BE_STRING));
	zend_string_release(property_name_name);

	zval property_age_default_value;
	ZVAL_NULL(&property_age_default_value);
	zend_string *property_age_name = zend_string_init("age", sizeof("age") - 1, 1);
	zend_declare_typed_property(class_entry, property_age_name, &property_age_default_value, ZEND_ACC_PUBLIC, NULL, (zend_type) ZEND_TYPE_INIT_MASK(MAY_BE_LONG|MAY_BE_NULL));
	zend_string_release(property_age_name);

	zend_string *attribute_name_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0 = zend_string_init_interned("MyPHPExt\\ExampleAttribute", sizeof("MyPHPExt\\ExampleAttribute") - 1, 1);
	zend_attribute *attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0 = zend_add_class_attribute(class_entry, attribute_name_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0, 2);
	zend_string_release(attribute_name_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0);
	zval attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0_arg0;
	zend_string *attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0_arg0_str = zend_string_init("entity", strlen("entity"), 1);
	ZVAL_STR(&attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0_arg0, attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0_arg0_str);
	ZVAL_COPY_VALUE(&attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0->args[0].value, &attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0_arg0);
	zval attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0_arg1;
	zend_string *attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0_arg1_str = zend_string_init("primary user model", strlen("primary user model"), 1);
	ZVAL_STR(&attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0_arg1, attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0_arg1_str);
	ZVAL_COPY_VALUE(&attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0->args[1].value, &attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_0_arg1);

	zend_string *attribute_name_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_1 = zend_string_init_interned("MyPHPExt\\ExampleAttribute", sizeof("MyPHPExt\\ExampleAttribute") - 1, 1);
	zend_attribute *attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_1 = zend_add_class_attribute(class_entry, attribute_name_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_1, 1);
	zend_string_release(attribute_name_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_1);
	zval attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_1_arg0;
	zend_string *attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_1_arg0_str = zend_string_init("audited", strlen("audited"), 1);
	ZVAL_STR(&attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_1_arg0, attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_1_arg0_str);
	ZVAL_COPY_VALUE(&attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_1->args[0].value, &attribute_MyPHPExt_ExampleAttribute_class_MyPHPExt_User_1_arg0);


	zend_string *attribute_name_MyPHPExt_ExampleAttribute_func_handle_arg0_0 = zend_string_init_interned("MyPHPExt\\ExampleAttribute", sizeof("MyPHPExt\\ExampleAttribute") - 1, 1);
	zend_attribute *attribute_MyPHPExt_ExampleAttribute_func_handle_arg0_0 = zend_add_parameter_attribute(zend_hash_str_find_ptr(&class_entry->function_table, "handle", sizeof("handle") - 1), 0, attribute_name_MyPHPExt_ExampleAttribute_func_handle_arg0_0, 2);
	zend_string_release(attribute_name_MyPHPExt_ExampleAttribute_func_handle_arg0_0);
	zval attribute_MyPHPExt_ExampleAttribute_func_handle_arg0_0_arg0;
	zend_string *attribute_MyPHPExt_ExampleAttribute_func_handle_arg0_0_arg0_str = zend_string_init("identifier", strlen("identifier"), 1);
	ZVAL_STR(&attribute_MyPHPExt_ExampleAttribute_func_handle_arg0_0_arg0, attribute_MyPHPExt_ExampleAttribute_func_handle_arg0_0_arg0_str);
	ZVAL_COPY_VALUE(&attribute_MyPHPExt_ExampleAttribute_func_handle_arg0_0->args[0].value, &attribute_MyPHPExt_ExampleAttribute_func_handle_arg0_0_arg0);
	zval attribute_MyPHPExt_ExampleAttribute_func_handle_arg0_0_arg1;
	zend_string *attribute_MyPHPExt_ExampleAttribute_func_handle_arg0_0_arg1_str = zend_string_init("string or int", strlen("string or int"), 1);
	ZVAL_STR(&attribute_MyPHPExt_ExampleAttribute_func_handle_arg0_0_arg1, attribute_MyPHPExt_ExampleAttribute_func_handle_arg0_0_arg1_str);
	ZVAL_COPY_VALUE(&attribute_MyPHPExt_ExampleAttribute_func_handle_arg0_0->args[1].value, &attribute_MyPHPExt_ExampleAttribute_func_handle_arg0_0_arg1);

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_Dumper(void)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "Dumper", class_MyPHPExt_Dumper_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_Counter(void)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "Counter", class_MyPHPExt_Counter_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_FINAL;

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_ArrayLike(zend_class_entry *class_entry_ArrayAccess, zend_class_entry *class_entry_Countable, zend_class_entry *class_entry_Iterator)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "ArrayLike", class_MyPHPExt_ArrayLike_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	zend_class_implements(class_entry, 3, class_entry_ArrayAccess, class_entry_Countable, class_entry_Iterator);

	return class_entry;
}
