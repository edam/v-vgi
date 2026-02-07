module vgi

import os

// get_binding_dir_name converts library name and version to directory name
// E.g., "Gtk-4.0" becomes "gtk_4_0"
pub fn get_binding_dir_name(library string, version string) string {
	lib_lower := library.to_lower().replace('-', '_')
	ver_lower := version.replace('.', '_').replace('-', '_')
	return '${lib_lower}_${ver_lower}'
}

// generate_bindings generates V bindings for a library
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

	// Write README.md
	readme_path := os.join_path(binding_dir, 'README.md')
	typelib_path := repo.get_typelib_path(library)
	loaded_version := repo.get_version(library)

	readme_content := 'Library: ${library}
Version: ${loaded_version}
Typelib: ${typelib_path}
'

	os.write_file(readme_path, readme_content) or {
		eprintln('Error: Failed to write README.md')
		eprintln('${err}')
		exit(1)
	}

	// generate object bindings
	n_infos := repo.get_n_infos(library)

	for i in 0 .. int(n_infos) {
		info := repo.get_info(library, i) or { continue }

		if info.get_type() == 'object' {
			object_info := info.as_object_info()
			generate_object_binding(object_info, binding_dir)
		}

		info.free()
	}

	println('Generated bindings for ${library}-${version} in ${dir_name}/')
}

// generate_object_binding generates V file for an object
fn generate_object_binding(info ObjectInfo, binding_dir string) {
	object_name := info.get_name()
	file_name := object_name.to_lower() + '.v'
	file_path := os.join_path(binding_dir, file_name)
	current_namespace := info.get_namespace()

	mut content := 'module ${os.file_name(binding_dir)}\n'

	// get parent and check if cross-namespace
	parent := info.get_parent()
	mut parent_embed := ''
	mut parent_name := ''

	if p := parent {
		parent_name = p.get_name()
		parent_namespace := p.get_namespace()

		if parent_namespace != current_namespace {
			// cross-namespace parent - need import
			repo := get_default_repository()
			parent_version := repo.get_version(parent_namespace)
			parent_module := get_binding_dir_name(parent_namespace, parent_version)
			module_alias := parent_namespace.to_lower()

			content += '\nimport edam.vgi.${parent_module} as ${module_alias}\n'
			parent_embed = '${module_alias}.${parent_name}'
		} else {
			// same namespace - direct embed
			parent_embed = parent_name
		}
	}

	content += '\n'

	// struct with embedded parent
	content += '// ${object_name} struct\n'
	content += 'pub struct ${object_name} {\n'
	if parent_embed != '' {
		content += '\t${parent_embed}\n'
	} else {
		content += '\tptr voidptr\n'
	}
	content += '}\n\n'

	// properties struct
	content += generate_properties_struct(info, object_name, parent_name, parent_embed)

	// constructor
	content += generate_constructor(object_name)

	// property methods
	content += generate_property_methods(info, object_name)

	os.write_file(file_path, content) or {
		eprintln('Warning: Failed to write ${file_path}')
		return
	}
}

// generate_properties_struct generates [@params] properties struct
fn generate_properties_struct(info ObjectInfo, object_name string, parent_name string, parent_embed string) string {
	mut content := '// ${object_name}Properties for [@params] initialization\n'
	content += '[@params]\n'
	content += 'pub struct ${object_name}Properties {\n'

	if parent_embed != '' {
		content += '\t${parent_embed}Properties\n'
	}

	// add properties
	n_props := info.get_n_properties()
	for i in 0 .. int(n_props) {
		prop := info.get_property(u32(i)) or { continue }
		prop_name := prop.get_name()

		// convert kebab-case to snake_case
		v_prop_name := prop_name.replace('-', '_')

		// TODO: proper type mapping, using string for now
		content += '\t${v_prop_name} ?string\n'

		prop.free()
	}

	content += '}\n\n'
	return content
}

// generate_constructor generates Object.new() constructor stub
fn generate_constructor(object_name string) string {
	mut content := '// new creates a new ${object_name}\n'
	content += 'pub fn ${object_name}.new(properties ${object_name}Properties) &${object_name} {\n'
	content += '\t// TODO: Implement object construction with properties\n'
	content += '\tpanic("${object_name}.new() not yet implemented")\n'
	content += '}\n\n'
	return content
}

// generate_property_methods generates property getter/setter methods
fn generate_property_methods(info ObjectInfo, object_name string) string {
	mut content := ''

	n_props := info.get_n_properties()
	for i in 0 .. int(n_props) {
		prop := info.get_property(u32(i)) or { continue }
		prop_name := prop.get_name()
		v_prop_name := prop_name.replace('-', '_')

		// getter if readable
		if prop.is_readable() {
			content += '// get_${v_prop_name} gets the ${prop_name} property\n'
			content += 'pub fn (obj &${object_name}) get_${v_prop_name}() string {\n'
			content += '\t// TODO: Implement property getter\n'
			content += '\tpanic("get_${v_prop_name}() not yet implemented")\n'
			content += '}\n\n'
		}

		// setter if writable
		if prop.is_writable() {
			content += '// set_${v_prop_name} sets the ${prop_name} property\n'
			content += 'pub fn (obj &${object_name}) set_${v_prop_name}(value string) {\n'
			content += '\t// TODO: Implement property setter\n'
			content += '\tpanic("set_${v_prop_name}() not yet implemented")\n'
			content += '}\n\n'
		}

		prop.free()
	}

	return content
}
