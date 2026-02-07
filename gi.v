module vgi

// Repository represents a GIRepository instance
pub struct Repository {
	ptr &C.GIRepository
}

// get_default_repository returns the default GIRepository singleton
pub fn get_default_repository() Repository {
	return Repository{
		ptr: C.gi_repository_dup_default()
	}
}

// require loads a namespace with the given version
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

// get_n_infos returns the number of metadata entries in the namespace
pub fn (r Repository) get_n_infos(namespace string) u32 {
	return C.gi_repository_get_n_infos(r.ptr, namespace.str)
}

// get_typelib_path returns the full path to the typelib file for a namespace
pub fn (r Repository) get_typelib_path(namespace string) string {
	path := C.gi_repository_get_typelib_path(r.ptr, namespace.str)
	if path == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(path) }
}

// get_version returns the version of a loaded namespace
pub fn (r Repository) get_version(namespace string) string {
	version := C.gi_repository_get_version(r.ptr, namespace.str)
	if version == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(version) }
}

// get_info returns the metadata info at the given index
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

// free unreferences the info
pub fn (info &BaseInfo) free() {
	if info.ptr != unsafe { nil } {
		C.gi_base_info_unref(info.ptr)
	}
}

// get_name returns the name of the info
pub fn (info BaseInfo) get_name() string {
	name := C.gi_base_info_get_name(info.ptr)
	if name == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(name) }
}

// get_namespace returns the namespace of the info
pub fn (info BaseInfo) get_namespace() string {
	namespace := C.gi_base_info_get_namespace(info.ptr)
	if namespace == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(namespace) }
}

// get_type_name returns the GObject type name of the info (e.g., "GIFunctionInfo", "GIObjectInfo")
pub fn (info BaseInfo) get_type_name() string {
	type_name := C.G_OBJECT_TYPE_NAME(info.ptr)
	if type_name == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(type_name) }
}

// get_type returns a simplified type string (e.g., "function", "object")
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

// as_object_info casts BaseInfo to ObjectInfo
pub fn (info BaseInfo) as_object_info() ObjectInfo {
	return ObjectInfo{
		BaseInfo: info
	}
}

// get_parent returns the parent object info, if any
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

// get_n_properties returns the number of properties
pub fn (info ObjectInfo) get_n_properties() u32 {
	return C.gi_object_info_get_n_properties(&C.GIObjectInfo(info.ptr))
}

// get_property returns property info at index
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

// PropertyInfo represents a GIPropertyInfo
pub struct PropertyInfo {
	BaseInfo
}

// is_readable returns true if the property is readable
pub fn (info PropertyInfo) is_readable() bool {
	flags := C.gi_property_info_get_flags(&C.GIPropertyInfo(info.ptr))
	return (flags & gi_property_readable) != 0
}

// is_writable returns true if the property is writable
pub fn (info PropertyInfo) is_writable() bool {
	flags := C.gi_property_info_get_flags(&C.GIPropertyInfo(info.ptr))
	return (flags & gi_property_writable) != 0
}

// get_type_info returns the type information for the property
pub fn (info PropertyInfo) get_type_info() TypeInfo {
	type_ptr := C.gi_property_info_get_type_info(&C.GIPropertyInfo(info.ptr))
	return TypeInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(type_ptr)
		}
	}
}

// get_v_type returns the V type string for the property
pub fn (info PropertyInfo) get_v_type() string {
	type_info := info.get_type_info()
	v_type := type_info.to_v_type()
	type_info.free()
	return v_type
}

// TypeInfo represents a GITypeInfo
pub struct TypeInfo {
	BaseInfo
}

// get_tag returns the type tag
pub fn (info TypeInfo) get_tag() int {
	return C.gi_type_info_get_tag(&C.GITypeInfo(info.ptr))
}

// to_v_type converts the type to a V type string for use in generated code
pub fn (info TypeInfo) to_v_type() string {
	tag := info.get_tag()
	return match tag {
		gi_type_tag_void { 'voidptr' }
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
		gi_type_tag_utf8, gi_type_tag_filename { 'string' }
		gi_type_tag_gtype { 'u64' } // GType is typedef'd as size_t
		else { 'voidptr' } // TODO: handle arrays, interfaces, lists, etc.
	}
}
