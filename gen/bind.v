module gen

import os

// generate V bindings for a library
pub fn generate_bindings(library string, version string) {
	repo := get_default_repository()

	// load library
	repo.require(library, version) or {
		eprintln('Error: Failed to load library ${library}-${version}')
		eprintln('${err}')
		exit(1)
	}

	// get binding directory name
	dir_name := get_binding_dir_name(library, version)
	binding_dir := get_vmod_path(dir_name)

	// create/empty directory
	if os.exists(binding_dir) {
		os.rmdir_all(binding_dir) or {
			eprintln('Error: Failed to remove existing directory ${binding_dir}')
			eprintln('${err}')
			exit(1)
		}
	}

	os.mkdir_all(binding_dir) or {
		eprintln('Error: Failed to create directory ${binding_dir}')
		eprintln('${err}')
		exit(1)
	}

	// get metadata for generation
	typelib_path := repo.get_typelib_path(library)
	loaded_version := repo.get_version(library)

	// generate helper files
	generate_readme(binding_dir, library, loaded_version, typelib_path)
	generate_v_util(binding_dir)
	generate_compat_c(binding_dir, library, loaded_version)

	// generate object and interface bindings
	n_infos := repo.get_n_infos(library)

	for i in 0 .. int(n_infos) {
		info := repo.get_info(library, i) or { continue }

		match info.get_type() {
			'object' {
				object_info := info.as_object_info()
				generate_object_binding(object_info, binding_dir)
			}
			'interface' {
				interface_info := info.as_interface_info()
				generate_interface_binding(interface_info, binding_dir)
			}
			'enum', 'flags' {
				enum_info := info.as_enum_info()
				generate_enum_binding(enum_info, binding_dir)
			}
			else {}
		}

		info.free()
	}

	module_parts := @MOD.split('.')
	base_module := module_parts[..module_parts.len - 1].join('.')
	println('bindings for ${library}-${version} generated at ${base_module}.${dir_name}')
}
