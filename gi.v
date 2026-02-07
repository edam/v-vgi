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
