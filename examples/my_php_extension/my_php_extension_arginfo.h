/* This is a generated file, edit the .stub.php file instead.
 * Stub hash: ba87d13bceef0140a0cc97bbc91d3d4a8b203335 */

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_hello, 0, 0, IS_VOID, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_greet, 0, 1, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_MyPHPExt_increment, 0, 1, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(1, value, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, by, IS_LONG, 0, "1")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_MyPHPExt_mapValues, 0, 2, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, values, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, mapper, IS_CALLABLE, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_MyPHPExt_Test_allocatorBailout, 0, 0, IS_ARRAY, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Identifiable_getId, 0, 0, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_MyPHPExt_Tag___construct, 0, 0, 1)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, description, IS_STRING, 1, "null")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_MyPHPExt_Entity___construct, 0, 0, 1)
	ZEND_ARG_TYPE_INFO(0, id, IS_LONG, 0)
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_Entity_getId arginfo_class_MyPHPExt_Identifiable_getId

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Entity_label, 0, 0, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_MyPHPExt_User___construct, 0, 0, 2)
	ZEND_ARG_TYPE_INFO(0, id, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, age, IS_LONG, 1, "null")
	ZEND_ARG_OBJ_INFO_WITH_DEFAULT_VALUE(0, role, MyPHPExt\\Role, 0, "MyPHPExt\\Role::User")
	ZEND_ARG_OBJ_INFO_WITH_DEFAULT_VALUE(0, status, MyPHPExt\\Status, 0, "MyPHPExt\\Status::Active")
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_User_label arginfo_class_MyPHPExt_Entity_label

#define arginfo_class_MyPHPExt_User___toString arginfo_class_MyPHPExt_Entity_label

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_MyPHPExt_Counter___construct, 0, 0, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, value, IS_LONG, 0, "0")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Counter_increment, 0, 0, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, by, IS_LONG, 0, "1")
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_Counter_decrement arginfo_class_MyPHPExt_Counter_increment

#define arginfo_class_MyPHPExt_Counter_value arginfo_class_MyPHPExt_Identifiable_getId

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Counter_reset, 0, 0, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, value, IS_LONG, 0, "0")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Dumper_dump, 0, 0, IS_VOID, 0)
	ZEND_ARG_VARIADIC_TYPE_INFO(0, values, IS_MIXED, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_MyPHPExt_Collection___construct, 0, 0, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, values, IS_ARRAY, 0, "[]")
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_Collection_toArray arginfo_MyPHPExt_Test_allocatorBailout

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Collection_offsetExists, 0, 1, _IS_BOOL, 0)
	ZEND_ARG_TYPE_INFO(0, offset, IS_MIXED, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Collection_offsetGet, 0, 1, IS_MIXED, 0)
	ZEND_ARG_TYPE_INFO(0, offset, IS_MIXED, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Collection_offsetSet, 0, 2, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(0, offset, IS_MIXED, 0)
	ZEND_ARG_TYPE_INFO(0, value, IS_MIXED, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Collection_offsetUnset, 0, 1, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(0, offset, IS_MIXED, 0)
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_Collection_count arginfo_class_MyPHPExt_Identifiable_getId

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Collection_current, 0, 0, IS_MIXED, 0)
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_Collection_key arginfo_class_MyPHPExt_Collection_current

#define arginfo_class_MyPHPExt_Collection_next arginfo_hello

#define arginfo_class_MyPHPExt_Collection_rewind arginfo_hello

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_MyPHPExt_Collection_valid, 0, 0, _IS_BOOL, 0)
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_Config_greeting arginfo_class_MyPHPExt_Entity_label

#define arginfo_class_MyPHPExt_Config_maxUsers arginfo_class_MyPHPExt_Identifiable_getId

#define arginfo_class_MyPHPExt_Config_debugEnabled arginfo_class_MyPHPExt_Collection_valid

#define arginfo_class_MyPHPExt_Config_mode arginfo_class_MyPHPExt_Entity_label

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_MyPHPExt_Metrics___construct, 0, 0, 0)
ZEND_END_ARG_INFO()

#define arginfo_class_MyPHPExt_Metrics_snapshot arginfo_MyPHPExt_Test_allocatorBailout

#define arginfo_class_MyPHPExt_Metrics_reset arginfo_hello


ZEND_FUNCTION(hello);
ZEND_FUNCTION(greet);
ZEND_FUNCTION(MyPHPExt_increment);
ZEND_FUNCTION(MyPHPExt_mapValues);
ZEND_FUNCTION(MyPHPExt_Test_allocatorBailout);
ZEND_METHOD(MyPHPExt_Tag, __construct);
ZEND_METHOD(MyPHPExt_Entity, __construct);
ZEND_METHOD(MyPHPExt_Entity, getId);
ZEND_METHOD(MyPHPExt_User, __construct);
ZEND_METHOD(MyPHPExt_User, label);
ZEND_METHOD(MyPHPExt_User, __toString);
ZEND_METHOD(MyPHPExt_Counter, __construct);
ZEND_METHOD(MyPHPExt_Counter, increment);
ZEND_METHOD(MyPHPExt_Counter, decrement);
ZEND_METHOD(MyPHPExt_Counter, value);
ZEND_METHOD(MyPHPExt_Counter, reset);
ZEND_METHOD(MyPHPExt_Dumper, dump);
ZEND_METHOD(MyPHPExt_Collection, __construct);
ZEND_METHOD(MyPHPExt_Collection, toArray);
ZEND_METHOD(MyPHPExt_Collection, offsetExists);
ZEND_METHOD(MyPHPExt_Collection, offsetGet);
ZEND_METHOD(MyPHPExt_Collection, offsetSet);
ZEND_METHOD(MyPHPExt_Collection, offsetUnset);
ZEND_METHOD(MyPHPExt_Collection, count);
ZEND_METHOD(MyPHPExt_Collection, current);
ZEND_METHOD(MyPHPExt_Collection, key);
ZEND_METHOD(MyPHPExt_Collection, next);
ZEND_METHOD(MyPHPExt_Collection, rewind);
ZEND_METHOD(MyPHPExt_Collection, valid);
ZEND_METHOD(MyPHPExt_Config, greeting);
ZEND_METHOD(MyPHPExt_Config, maxUsers);
ZEND_METHOD(MyPHPExt_Config, debugEnabled);
ZEND_METHOD(MyPHPExt_Config, mode);
ZEND_METHOD(MyPHPExt_Metrics, __construct);
ZEND_METHOD(MyPHPExt_Metrics, snapshot);
ZEND_METHOD(MyPHPExt_Metrics, reset);


static const zend_function_entry ext_functions[] = {
	ZEND_FE(hello, arginfo_hello)
	ZEND_FE(greet, arginfo_greet)
	ZEND_NS_FALIAS("MyPHPExt", increment, MyPHPExt_increment, arginfo_MyPHPExt_increment)
	ZEND_NS_FALIAS("MyPHPExt", mapValues, MyPHPExt_mapValues, arginfo_MyPHPExt_mapValues)
	ZEND_NS_FALIAS("MyPHPExt\\Test", allocatorBailout, MyPHPExt_Test_allocatorBailout, arginfo_MyPHPExt_Test_allocatorBailout)
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


static const zend_function_entry class_MyPHPExt_Tag_methods[] = {
	ZEND_ME(MyPHPExt_Tag, __construct, arginfo_class_MyPHPExt_Tag___construct, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_Entity_methods[] = {
	ZEND_ME(MyPHPExt_Entity, __construct, arginfo_class_MyPHPExt_Entity___construct, ZEND_ACC_PROTECTED)
	ZEND_ME(MyPHPExt_Entity, getId, arginfo_class_MyPHPExt_Entity_getId, ZEND_ACC_PUBLIC|ZEND_ACC_FINAL)
	ZEND_ABSTRACT_ME_WITH_FLAGS(MyPHPExt_Entity, label, arginfo_class_MyPHPExt_Entity_label, ZEND_ACC_PUBLIC|ZEND_ACC_ABSTRACT)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_User_methods[] = {
	ZEND_ME(MyPHPExt_User, __construct, arginfo_class_MyPHPExt_User___construct, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_User, label, arginfo_class_MyPHPExt_User_label, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_User, __toString, arginfo_class_MyPHPExt_User___toString, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_Counter_methods[] = {
	ZEND_ME(MyPHPExt_Counter, __construct, arginfo_class_MyPHPExt_Counter___construct, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Counter, increment, arginfo_class_MyPHPExt_Counter_increment, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Counter, decrement, arginfo_class_MyPHPExt_Counter_decrement, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Counter, value, arginfo_class_MyPHPExt_Counter_value, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Counter, reset, arginfo_class_MyPHPExt_Counter_reset, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_Dumper_methods[] = {
	ZEND_ME(MyPHPExt_Dumper, dump, arginfo_class_MyPHPExt_Dumper_dump, ZEND_ACC_PUBLIC|ZEND_ACC_STATIC)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_Collection_methods[] = {
	ZEND_ME(MyPHPExt_Collection, __construct, arginfo_class_MyPHPExt_Collection___construct, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Collection, toArray, arginfo_class_MyPHPExt_Collection_toArray, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Collection, offsetExists, arginfo_class_MyPHPExt_Collection_offsetExists, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Collection, offsetGet, arginfo_class_MyPHPExt_Collection_offsetGet, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Collection, offsetSet, arginfo_class_MyPHPExt_Collection_offsetSet, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Collection, offsetUnset, arginfo_class_MyPHPExt_Collection_offsetUnset, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Collection, count, arginfo_class_MyPHPExt_Collection_count, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Collection, current, arginfo_class_MyPHPExt_Collection_current, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Collection, key, arginfo_class_MyPHPExt_Collection_key, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Collection, next, arginfo_class_MyPHPExt_Collection_next, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Collection, rewind, arginfo_class_MyPHPExt_Collection_rewind, ZEND_ACC_PUBLIC)
	ZEND_ME(MyPHPExt_Collection, valid, arginfo_class_MyPHPExt_Collection_valid, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_Config_methods[] = {
	ZEND_ME(MyPHPExt_Config, greeting, arginfo_class_MyPHPExt_Config_greeting, ZEND_ACC_PUBLIC|ZEND_ACC_STATIC)
	ZEND_ME(MyPHPExt_Config, maxUsers, arginfo_class_MyPHPExt_Config_maxUsers, ZEND_ACC_PUBLIC|ZEND_ACC_STATIC)
	ZEND_ME(MyPHPExt_Config, debugEnabled, arginfo_class_MyPHPExt_Config_debugEnabled, ZEND_ACC_PUBLIC|ZEND_ACC_STATIC)
	ZEND_ME(MyPHPExt_Config, mode, arginfo_class_MyPHPExt_Config_mode, ZEND_ACC_PUBLIC|ZEND_ACC_STATIC)
	ZEND_FE_END
};


static const zend_function_entry class_MyPHPExt_Metrics_methods[] = {
	ZEND_ME(MyPHPExt_Metrics, __construct, arginfo_class_MyPHPExt_Metrics___construct, ZEND_ACC_PRIVATE)
	ZEND_ME(MyPHPExt_Metrics, snapshot, arginfo_class_MyPHPExt_Metrics_snapshot, ZEND_ACC_PUBLIC|ZEND_ACC_STATIC)
	ZEND_ME(MyPHPExt_Metrics, reset, arginfo_class_MyPHPExt_Metrics_reset, ZEND_ACC_PUBLIC|ZEND_ACC_STATIC)
	ZEND_FE_END
};

static void register_my_php_extension_symbols(int module_number)
{
	REGISTER_STRING_CONSTANT("MyPHPExt\\VERSION", "0.1.0", CONST_PERSISTENT);
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

	zval enum_case_Inactive_value;
	ZVAL_LONG(&enum_case_Inactive_value, 0);
	zend_enum_add_case_cstr(class_entry, "Inactive", &enum_case_Inactive_value);

	zval enum_case_Active_value;
	ZVAL_LONG(&enum_case_Active_value, 1);
	zend_enum_add_case_cstr(class_entry, "Active", &enum_case_Active_value);

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_Role(void)
{
	zend_class_entry *class_entry = zend_register_internal_enum("MyPHPExt\\Role", IS_STRING, class_MyPHPExt_Role_methods);

	zval enum_case_User_value;
	zend_string *enum_case_User_value_str = zend_string_init("user", strlen("user"), 1);
	ZVAL_STR(&enum_case_User_value, enum_case_User_value_str);
	zend_enum_add_case_cstr(class_entry, "User", &enum_case_User_value);

	zval enum_case_Admin_value;
	zend_string *enum_case_Admin_value_str = zend_string_init("admin", strlen("admin"), 1);
	ZVAL_STR(&enum_case_Admin_value, enum_case_Admin_value_str);
	zend_enum_add_case_cstr(class_entry, "Admin", &enum_case_Admin_value);

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_Tag(void)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "Tag", class_MyPHPExt_Tag_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_FINAL;

	zval property_name_default_value;
	ZVAL_UNDEF(&property_name_default_value);
	zend_string *property_name_name = zend_string_init("name", sizeof("name") - 1, 1);
	zend_declare_typed_property(class_entry, property_name_name, &property_name_default_value, ZEND_ACC_PUBLIC, NULL, (zend_type) ZEND_TYPE_INIT_MASK(MAY_BE_STRING));
	zend_string_release(property_name_name);

	zval property_description_default_value;
	ZVAL_UNDEF(&property_description_default_value);
	zend_string *property_description_name = zend_string_init("description", sizeof("description") - 1, 1);
	zend_declare_typed_property(class_entry, property_description_name, &property_description_default_value, ZEND_ACC_PUBLIC, NULL, (zend_type) ZEND_TYPE_INIT_MASK(MAY_BE_STRING|MAY_BE_NULL));
	zend_string_release(property_description_name);

	zend_string *attribute_name_Attribute_class_MyPHPExt_Tag_0 = zend_string_init_interned("Attribute", sizeof("Attribute") - 1, 1);
	zend_attribute *attribute_Attribute_class_MyPHPExt_Tag_0 = zend_add_class_attribute(class_entry, attribute_name_Attribute_class_MyPHPExt_Tag_0, 1);
	zend_string_release(attribute_name_Attribute_class_MyPHPExt_Tag_0);
	zval attribute_Attribute_class_MyPHPExt_Tag_0_arg0;
	ZVAL_LONG(&attribute_Attribute_class_MyPHPExt_Tag_0_arg0, ZEND_ATTRIBUTE_TARGET_CLASS | ZEND_ATTRIBUTE_TARGET_PARAMETER | ZEND_ATTRIBUTE_IS_REPEATABLE);
	ZVAL_COPY_VALUE(&attribute_Attribute_class_MyPHPExt_Tag_0->args[0].value, &attribute_Attribute_class_MyPHPExt_Tag_0_arg0);

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_Entity(zend_class_entry *class_entry_MyPHPExt_Identifiable)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "Entity", class_MyPHPExt_Entity_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_ABSTRACT;
	zend_class_implements(class_entry, 1, class_entry_MyPHPExt_Identifiable);

	zval property_id_default_value;
	ZVAL_UNDEF(&property_id_default_value);
	zend_string *property_id_name = zend_string_init("id", sizeof("id") - 1, 1);
	zend_declare_typed_property(class_entry, property_id_name, &property_id_default_value, ZEND_ACC_PROTECTED, NULL, (zend_type) ZEND_TYPE_INIT_MASK(MAY_BE_LONG));
	zend_string_release(property_id_name);

	zend_string *attribute_name_MyPHPExt_Tag_class_MyPHPExt_Entity_0 = zend_string_init_interned("MyPHPExt\\Tag", sizeof("MyPHPExt\\Tag") - 1, 1);
	zend_attribute *attribute_MyPHPExt_Tag_class_MyPHPExt_Entity_0 = zend_add_class_attribute(class_entry, attribute_name_MyPHPExt_Tag_class_MyPHPExt_Entity_0, 1);
	zend_string_release(attribute_name_MyPHPExt_Tag_class_MyPHPExt_Entity_0);
	zval attribute_MyPHPExt_Tag_class_MyPHPExt_Entity_0_arg0;
	zend_string *attribute_MyPHPExt_Tag_class_MyPHPExt_Entity_0_arg0_str = zend_string_init("entity", strlen("entity"), 1);
	ZVAL_STR(&attribute_MyPHPExt_Tag_class_MyPHPExt_Entity_0_arg0, attribute_MyPHPExt_Tag_class_MyPHPExt_Entity_0_arg0_str);
	ZVAL_COPY_VALUE(&attribute_MyPHPExt_Tag_class_MyPHPExt_Entity_0->args[0].value, &attribute_MyPHPExt_Tag_class_MyPHPExt_Entity_0_arg0);

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_User(zend_class_entry *class_entry_MyPHPExt_Entity, zend_class_entry *class_entry_Stringable)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "User", class_MyPHPExt_User_methods);
	class_entry = zend_register_internal_class_ex(&ce, class_entry_MyPHPExt_Entity);
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
	ZVAL_UNDEF(&property_age_default_value);
	zend_string *property_age_name = zend_string_init("age", sizeof("age") - 1, 1);
	zend_declare_typed_property(class_entry, property_age_name, &property_age_default_value, ZEND_ACC_PUBLIC, NULL, (zend_type) ZEND_TYPE_INIT_MASK(MAY_BE_LONG|MAY_BE_NULL));
	zend_string_release(property_age_name);

	zval property_role_default_value;
	ZVAL_UNDEF(&property_role_default_value);
	zend_string *property_role_name = zend_string_init("role", sizeof("role") - 1, 1);
	zend_string *property_role_class_MyPHPExt_Role = zend_string_init("MyPHPExt\\Role", sizeof("MyPHPExt\\Role")-1, 1);
	zend_declare_typed_property(class_entry, property_role_name, &property_role_default_value, ZEND_ACC_PUBLIC, NULL, (zend_type) ZEND_TYPE_INIT_CLASS(property_role_class_MyPHPExt_Role, 0, 0));
	zend_string_release(property_role_name);

	zval property_status_default_value;
	ZVAL_UNDEF(&property_status_default_value);
	zend_string *property_status_name = zend_string_init("status", sizeof("status") - 1, 1);
	zend_string *property_status_class_MyPHPExt_Status = zend_string_init("MyPHPExt\\Status", sizeof("MyPHPExt\\Status")-1, 1);
	zend_declare_typed_property(class_entry, property_status_name, &property_status_default_value, ZEND_ACC_PUBLIC, NULL, (zend_type) ZEND_TYPE_INIT_CLASS(property_status_class_MyPHPExt_Status, 0, 0));
	zend_string_release(property_status_name);

	zend_string *attribute_name_MyPHPExt_Tag_class_MyPHPExt_User_0 = zend_string_init_interned("MyPHPExt\\Tag", sizeof("MyPHPExt\\Tag") - 1, 1);
	zend_attribute *attribute_MyPHPExt_Tag_class_MyPHPExt_User_0 = zend_add_class_attribute(class_entry, attribute_name_MyPHPExt_Tag_class_MyPHPExt_User_0, 2);
	zend_string_release(attribute_name_MyPHPExt_Tag_class_MyPHPExt_User_0);
	zval attribute_MyPHPExt_Tag_class_MyPHPExt_User_0_arg0;
	zend_string *attribute_MyPHPExt_Tag_class_MyPHPExt_User_0_arg0_str = zend_string_init("model", strlen("model"), 1);
	ZVAL_STR(&attribute_MyPHPExt_Tag_class_MyPHPExt_User_0_arg0, attribute_MyPHPExt_Tag_class_MyPHPExt_User_0_arg0_str);
	ZVAL_COPY_VALUE(&attribute_MyPHPExt_Tag_class_MyPHPExt_User_0->args[0].value, &attribute_MyPHPExt_Tag_class_MyPHPExt_User_0_arg0);
	zval attribute_MyPHPExt_Tag_class_MyPHPExt_User_0_arg1;
	zend_string *attribute_MyPHPExt_Tag_class_MyPHPExt_User_0_arg1_str = zend_string_init("Demonstrates properties, inheritance, enums, and attributes", strlen("Demonstrates properties, inheritance, enums, and attributes"), 1);
	ZVAL_STR(&attribute_MyPHPExt_Tag_class_MyPHPExt_User_0_arg1, attribute_MyPHPExt_Tag_class_MyPHPExt_User_0_arg1_str);
	ZVAL_COPY_VALUE(&attribute_MyPHPExt_Tag_class_MyPHPExt_User_0->args[1].value, &attribute_MyPHPExt_Tag_class_MyPHPExt_User_0_arg1);


	zend_string *attribute_name_MyPHPExt_Tag_func___construct_arg0_0 = zend_string_init_interned("MyPHPExt\\Tag", sizeof("MyPHPExt\\Tag") - 1, 1);
	zend_attribute *attribute_MyPHPExt_Tag_func___construct_arg0_0 = zend_add_parameter_attribute(zend_hash_str_find_ptr(&class_entry->function_table, "__construct", sizeof("__construct") - 1), 0, attribute_name_MyPHPExt_Tag_func___construct_arg0_0, 1);
	zend_string_release(attribute_name_MyPHPExt_Tag_func___construct_arg0_0);
	zval attribute_MyPHPExt_Tag_func___construct_arg0_0_arg0;
	zend_string *attribute_MyPHPExt_Tag_func___construct_arg0_0_arg0_str = zend_string_init("identifier", strlen("identifier"), 1);
	ZVAL_STR(&attribute_MyPHPExt_Tag_func___construct_arg0_0_arg0, attribute_MyPHPExt_Tag_func___construct_arg0_0_arg0_str);
	ZVAL_COPY_VALUE(&attribute_MyPHPExt_Tag_func___construct_arg0_0->args[0].value, &attribute_MyPHPExt_Tag_func___construct_arg0_0_arg0);

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

static zend_class_entry *register_class_MyPHPExt_Dumper(void)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "Dumper", class_MyPHPExt_Dumper_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_FINAL;

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_Collection(zend_class_entry *class_entry_ArrayAccess, zend_class_entry *class_entry_Countable, zend_class_entry *class_entry_Iterator)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "Collection", class_MyPHPExt_Collection_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_FINAL;
	zend_class_implements(class_entry, 3, class_entry_ArrayAccess, class_entry_Countable, class_entry_Iterator);

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_Config(void)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "Config", class_MyPHPExt_Config_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_FINAL;

	return class_entry;
}

static zend_class_entry *register_class_MyPHPExt_Metrics(void)
{
	zend_class_entry ce, *class_entry;

	INIT_NS_CLASS_ENTRY(ce, "MyPHPExt", "Metrics", class_MyPHPExt_Metrics_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);
	class_entry->ce_flags |= ZEND_ACC_FINAL;

	return class_entry;
}
