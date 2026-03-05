module gen

// Repository represents a GIRepository instance
pub struct Repository {
	ptr &C.GIRepository
}

// return the default GIRepository singleton
pub fn get_default_repository() Repository {
	return Repository{
		ptr: C.gi_repository_dup_default()
	}
}

// loads a namespace with the given version
pub fn (r Repository) require(namespace string, version string) ! {
	mut gerror := &C.GError(unsafe { nil })
	result := C.gi_repository_require(r.ptr, namespace.str, version.str, 0, &gerror)

	if result == unsafe { nil } {
		if gerror != unsafe { nil } {
			msg := unsafe { cstring_to_vstring(gerror.message) }
			C.g_error_free(gerror)
			return error(msg)
		}
		return error('Failed to load namespace ${namespace} version ${version}')
	}
}

// return the number of metadata entries in the namespace
pub fn (r Repository) get_n_infos(namespace string) u32 {
	return C.gi_repository_get_n_infos(r.ptr, namespace.str)
}

// return the full path to the typelib file for a namespace
pub fn (r Repository) get_typelib_path(namespace string) string {
	path := C.gi_repository_get_typelib_path(r.ptr, namespace.str)
	if path == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(path) }
}

// return the version of a loaded namespace
pub fn (r Repository) get_version(namespace string) string {
	version := C.gi_repository_get_version(r.ptr, namespace.str)
	if version == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(version) }
}

// return the metadata info at the given index
pub fn (r Repository) get_info(namespace string, index int) ?BaseInfo {
	info_ptr := C.gi_repository_get_info(r.ptr, namespace.str, index)
	if info_ptr == unsafe { nil } {
		return none
	}
	return BaseInfo{
		ptr: info_ptr
	}
}

// BaseInfo represents a GIBaseInfo metadata entry
pub struct BaseInfo {
	ptr &C.GIBaseInfo
}

// unreferences the info
pub fn (info &BaseInfo) free() {
	if info.ptr != unsafe { nil } {
		C.gi_base_info_unref(info.ptr)
	}
}

// return the name of the info
pub fn (info BaseInfo) get_name() string {
	name := C.gi_base_info_get_name(info.ptr)
	if name == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(name) }
}

// return the namespace of the info
pub fn (info BaseInfo) get_namespace() string {
	namespace := C.gi_base_info_get_namespace(info.ptr)
	if namespace == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(namespace) }
}

// return the GObject type name of the info (e.g., "GIFunctionInfo", "GIObjectInfo")
pub fn (info BaseInfo) get_type_name() string {
	type_name := C.G_OBJECT_TYPE_NAME(info.ptr)
	if type_name == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(type_name) }
}

// return a simplified type string (e.g., "function", "object")
pub fn (info BaseInfo) get_type() string {
	type_name := info.get_type_name()
	// GIFunctionInfo -> function, GIObjectInfo -> object, etc.
	if type_name.starts_with('GI') && type_name.ends_with('Info') {
		// Extract middle part and lowercase it
		middle := type_name[2..type_name.len - 4]
		return middle.to_lower()
	}
	return type_name
}

// ObjectInfo represents a GIObjectInfo
pub struct ObjectInfo {
	BaseInfo
}

// casts BaseInfo to ObjectInfo
pub fn (info BaseInfo) as_object_info() ObjectInfo {
	return ObjectInfo{
		BaseInfo: info
	}
}

// return the parent object info, if any
pub fn (info ObjectInfo) get_parent() ?ObjectInfo {
	parent_ptr := C.gi_object_info_get_parent(&C.GIObjectInfo(info.ptr))
	if parent_ptr == unsafe { nil } {
		return none
	}
	return ObjectInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(parent_ptr)
		}
	}
}

// return the number of properties
pub fn (info ObjectInfo) get_n_properties() u32 {
	return C.gi_object_info_get_n_properties(&C.GIObjectInfo(info.ptr))
}

// return property info at index
pub fn (info ObjectInfo) get_property(n u32) ?PropertyInfo {
	prop_ptr := C.gi_object_info_get_property(&C.GIObjectInfo(info.ptr), n)
	if prop_ptr == unsafe { nil } {
		return none
	}
	return PropertyInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(prop_ptr)
		}
	}
}

// return the number of methods
pub fn (info ObjectInfo) get_n_methods() u32 {
	return C.gi_object_info_get_n_methods(&C.GIObjectInfo(info.ptr))
}

// return method info at index
pub fn (info ObjectInfo) get_method(n u32) ?FunctionInfo {
	method_ptr := C.gi_object_info_get_method(&C.GIObjectInfo(info.ptr), n)
	if method_ptr == unsafe { nil } {
		return none
	}
	return FunctionInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(method_ptr)
		}
	}
}

// return the number of interfaces implemented
pub fn (info ObjectInfo) get_n_interfaces() u32 {
	return C.gi_object_info_get_n_interfaces(&C.GIObjectInfo(info.ptr))
}

// return interface info at index
pub fn (info ObjectInfo) get_interface(n u32) ?InterfaceInfo {
	iface_ptr := C.gi_object_info_get_interface(&C.GIObjectInfo(info.ptr), n)
	if iface_ptr == unsafe { nil } {
		return none
	}
	return InterfaceInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(iface_ptr)
		}
	}
}

// return the type initialization function name
pub fn (info ObjectInfo) get_type_init() string {
	type_init := C.gi_registered_type_info_get_type_init_function_name(&C.GIRegisteredTypeInfo(info.ptr))
	if type_init == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(type_init) }
}

// PropertyInfo represents a GIPropertyInfo
pub struct PropertyInfo {
	BaseInfo
}

// return true if the property is readable
pub fn (info PropertyInfo) is_readable() bool {
	flags := C.gi_property_info_get_flags(&C.GIPropertyInfo(info.ptr))
	return (flags & gi_property_readable) != 0
}

// return true if the property is writable
pub fn (info PropertyInfo) is_writable() bool {
	flags := C.gi_property_info_get_flags(&C.GIPropertyInfo(info.ptr))
	return (flags & gi_property_writable) != 0
}

// return the type information for the property
pub fn (info PropertyInfo) get_type_info() TypeInfo {
	type_ptr := C.gi_property_info_get_type_info(&C.GIPropertyInfo(info.ptr))
	return TypeInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(type_ptr)
		}
	}
}

// return the V type string for the property
pub fn (info PropertyInfo) get_v_type() string {
	type_info := info.get_type_info()
	defer { type_info.free() }
	return type_info.to_v_type()
}

// return the GType constant name
pub fn (info PropertyInfo) get_gtype_constant() string {
	type_info := info.get_type_info()
	defer { type_info.free() }
	return type_info.to_gtype_constant()
}

// return the g_value_get_* function name
pub fn (info PropertyInfo) get_gvalue_getter() string {
	type_info := info.get_type_info()
	defer { type_info.free() }
	return type_info.to_gvalue_getter()
}

// return the g_value_set_* function name
pub fn (info PropertyInfo) get_gvalue_setter() string {
	type_info := info.get_type_info()
	defer { type_info.free() }
	return type_info.to_gvalue_setter()
}

// return true if property needs cstring conversion
pub fn (info PropertyInfo) needs_string_conversion() bool {
	type_info := info.get_type_info()
	defer { type_info.free() }
	return type_info.needs_string_conversion()
}

// return the helper function name prefix
pub fn (info PropertyInfo) get_property_helper_name() string {
	type_info := info.get_type_info()
	defer { type_info.free() }
	return type_info.to_property_helper_name()
}

// FunctionInfo represents a GIFunctionInfo
pub struct FunctionInfo {
	BaseInfo
}

// return the number of arguments
pub fn (info FunctionInfo) get_n_args() u32 {
	return C.gi_callable_info_get_n_args(&C.GICallableInfo(info.ptr))
}

// return argument info at index
pub fn (info FunctionInfo) get_arg(n u32) ?ArgInfo {
	arg_ptr := C.gi_callable_info_get_arg(&C.GICallableInfo(info.ptr), n)
	if arg_ptr == unsafe { nil } {
		return none
	}
	return ArgInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(arg_ptr)
		}
	}
}

// return the return type info
pub fn (info FunctionInfo) get_return_type() TypeInfo {
	type_ptr := C.gi_callable_info_get_return_type(&C.GICallableInfo(info.ptr))
	return TypeInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(type_ptr)
		}
	}
}

// return true if function can return null
pub fn (info FunctionInfo) may_return_null() bool {
	return C.gi_callable_info_may_return_null(&C.GICallableInfo(info.ptr))
}

// return true if return value should be skipped
pub fn (info FunctionInfo) skip_return() bool {
	return C.gi_callable_info_skip_return(&C.GICallableInfo(info.ptr))
}

// return true if the function can throw a GError
pub fn (info FunctionInfo) can_throw_gerror() bool {
	return C.gi_callable_info_can_throw_gerror(&C.GICallableInfo(info.ptr))
}

// return the C symbol name for the function
pub fn (info FunctionInfo) get_symbol() string {
	symbol := C.gi_function_info_get_symbol(&C.GIFunctionInfo(info.ptr))
	if symbol == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(symbol) }
}

// InterfaceInfo represents a GIInterfaceInfo
pub struct InterfaceInfo {
	BaseInfo
}

// casts BaseInfo to InterfaceInfo
pub fn (info BaseInfo) as_interface_info() InterfaceInfo {
	return InterfaceInfo{
		BaseInfo: info
	}
}

// return the number of methods
pub fn (info InterfaceInfo) get_n_methods() u32 {
	return C.gi_interface_info_get_n_methods(&C.GIInterfaceInfo(info.ptr))
}

// return method info at index
pub fn (info InterfaceInfo) get_method(n u32) ?FunctionInfo {
	method_ptr := C.gi_interface_info_get_method(&C.GIInterfaceInfo(info.ptr), n)
	if method_ptr == unsafe { nil } {
		return none
	}
	return FunctionInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(method_ptr)
		}
	}
}

// return the number of prerequisites (parent interfaces)
pub fn (info InterfaceInfo) get_n_prerequisites() u32 {
	return C.gi_interface_info_get_n_prerequisites(&C.GIInterfaceInfo(info.ptr))
}

// return prerequisite info at index
pub fn (info InterfaceInfo) get_prerequisite(n u32) ?BaseInfo {
	prereq_ptr := C.gi_interface_info_get_prerequisite(&C.GIInterfaceInfo(info.ptr), n)
	if prereq_ptr == unsafe { nil } {
		return none
	}
	return BaseInfo{
		ptr: prereq_ptr
	}
}

// EnumInfo represents a GIEnumInfo (enums and flags)
pub struct EnumInfo {
	BaseInfo
}

// casts BaseInfo to EnumInfo
pub fn (info BaseInfo) as_enum_info() EnumInfo {
	return EnumInfo{
		BaseInfo: info
	}
}

// return the number of values in the enum
pub fn (info EnumInfo) get_n_values() u32 {
	return C.gi_enum_info_get_n_values(&C.GIEnumInfo(info.ptr))
}

// return value info at index
pub fn (info EnumInfo) get_value(n u32) ?ValueInfo {
	value_ptr := C.gi_enum_info_get_value(&C.GIEnumInfo(info.ptr), n)
	if value_ptr == unsafe { nil } {
		return none
	}
	return ValueInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(value_ptr)
		}
	}
}

// return the storage type for the enum
pub fn (info EnumInfo) get_storage_type() int {
	return C.gi_enum_info_get_storage_type(&C.GIEnumInfo(info.ptr))
}

// ValueInfo represents a GIValueInfo (enum/flags value)
pub struct ValueInfo {
	BaseInfo
}

// return the integer value
pub fn (info ValueInfo) get_value() i64 {
	return C.gi_value_info_get_value(&C.GIValueInfo(info.ptr))
}

// ArgInfo represents a GIArgInfo
pub struct ArgInfo {
	BaseInfo
}

// return the argument direction (in/out/inout)
pub fn (info ArgInfo) get_direction() int {
	return C.gi_arg_info_get_direction(&C.GIArgInfo(info.ptr))
}

// return the type information for the argument
pub fn (info ArgInfo) get_type_info() TypeInfo {
	type_ptr := C.gi_arg_info_get_type_info(&C.GIArgInfo(info.ptr))
	return TypeInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(type_ptr)
		}
	}
}

// return true if argument can be null
pub fn (info ArgInfo) may_be_null() bool {
	return C.gi_arg_info_may_be_null(&C.GIArgInfo(info.ptr))
}

// return the V type string for the argument
pub fn (info ArgInfo) get_v_type() string {
	type_info := info.get_type_info()
	defer { type_info.free() }
	return type_info.to_v_type()
}

// TypeInfo represents a GITypeInfo
pub struct TypeInfo {
	BaseInfo
}

// return the type tag
pub fn (info TypeInfo) get_tag() int {
	return C.gi_type_info_get_tag(&C.GITypeInfo(info.ptr))
}

// return true if the type is a pointer
pub fn (info TypeInfo) is_pointer() bool {
	return C.gi_type_info_is_pointer(&C.GITypeInfo(info.ptr))
}

// converts the type to a V type string for use in generated code
pub fn (info TypeInfo) to_v_type() string {
	type_tag := info.get_tag()
	is_pointer := info.is_pointer()
	base_type := match type_tag {
		gi_type_tag_boolean { 'bool' }
		gi_type_tag_int8 { 'i8' }
		gi_type_tag_uint8 { 'u8' }
		gi_type_tag_int16 { 'i16' }
		gi_type_tag_uint16 { 'u16' }
		gi_type_tag_int32 { 'int' }
		gi_type_tag_uint32 { 'u32' }
		gi_type_tag_int64 { 'i64' }
		gi_type_tag_uint64 { 'u64' }
		gi_type_tag_float { 'f32' }
		gi_type_tag_double { 'f64' }
		gi_type_tag_gtype { 'u64' } // size_t
		gi_type_tag_void { return if is_pointer { 'voidptr' } else { 'void' } }
		gi_type_tag_utf8, gi_type_tag_filename { return 'string' }
		else { return 'voidptr' } // interfaces, arrays, lists, etc.
	}
	return if is_pointer { '&${base_type}' } else { base_type }
}

// return the GType constant name for code generation
pub fn (info TypeInfo) to_gtype_constant() string {
	tag := info.get_tag()
	return match tag {
		gi_type_tag_void { 'g_type_pointer' }
		gi_type_tag_boolean { 'g_type_boolean' }
		gi_type_tag_int8, gi_type_tag_int16, gi_type_tag_int32 { 'g_type_int' }
		gi_type_tag_uint8, gi_type_tag_uint16, gi_type_tag_uint32 { 'g_type_uint' }
		gi_type_tag_int64 { 'g_type_int64' }
		gi_type_tag_uint64, gi_type_tag_gtype { 'g_type_uint64' }
		gi_type_tag_float { 'g_type_float' }
		gi_type_tag_double { 'g_type_double' }
		gi_type_tag_utf8, gi_type_tag_filename { 'g_type_string' }
		else { 'g_type_pointer' }
	}
}

// return the g_value_get_* function name
pub fn (info TypeInfo) to_gvalue_getter() string {
	tag := info.get_tag()
	return match tag {
		gi_type_tag_boolean { 'g_value_get_boolean' }
		gi_type_tag_int8, gi_type_tag_int16, gi_type_tag_int32 { 'g_value_get_int' }
		gi_type_tag_uint8, gi_type_tag_uint16, gi_type_tag_uint32 { 'g_value_get_uint' }
		gi_type_tag_int64 { 'g_value_get_int64' }
		gi_type_tag_uint64, gi_type_tag_gtype { 'g_value_get_uint64' }
		gi_type_tag_float { 'g_value_get_float' }
		gi_type_tag_double { 'g_value_get_double' }
		gi_type_tag_utf8, gi_type_tag_filename { 'g_value_get_string' }
		else { 'g_value_get_pointer' }
	}
}

// return the g_value_set_* function name
pub fn (info TypeInfo) to_gvalue_setter() string {
	tag := info.get_tag()
	return match tag {
		gi_type_tag_boolean { 'g_value_set_boolean' }
		gi_type_tag_int8, gi_type_tag_int16, gi_type_tag_int32 { 'g_value_set_int' }
		gi_type_tag_uint8, gi_type_tag_uint16, gi_type_tag_uint32 { 'g_value_set_uint' }
		gi_type_tag_int64 { 'g_value_set_int64' }
		gi_type_tag_uint64, gi_type_tag_gtype { 'g_value_set_uint64' }
		gi_type_tag_float { 'g_value_set_float' }
		gi_type_tag_double { 'g_value_set_double' }
		gi_type_tag_utf8, gi_type_tag_filename { 'g_value_set_string' }
		else { 'g_value_set_pointer' }
	}
}

// return true if the type needs cstring conversion
pub fn (info TypeInfo) needs_string_conversion() bool {
	tag := info.get_tag()
	return tag == gi_type_tag_utf8 || tag == gi_type_tag_filename
}

// return the helper function name prefix (e.g., "bool", "int", "string")
pub fn (info TypeInfo) to_property_helper_name() string {
	tag := info.get_tag()
	return match tag {
		gi_type_tag_boolean { 'bool' }
		gi_type_tag_int8 { 'i8' }
		gi_type_tag_uint8 { 'u8' }
		gi_type_tag_int16, gi_type_tag_int32 { 'int' }
		gi_type_tag_uint16, gi_type_tag_uint32 { 'u32' }
		gi_type_tag_int64 { 'i64' }
		gi_type_tag_uint64, gi_type_tag_gtype { 'u64' }
		gi_type_tag_float { 'f32' }
		gi_type_tag_double { 'f64' }
		gi_type_tag_utf8, gi_type_tag_filename { 'string' }
		else { 'voidptr' }
	}
}
