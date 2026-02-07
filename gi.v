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
