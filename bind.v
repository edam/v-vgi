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

	// get metadata for generation
	typelib_path := repo.get_typelib_path(library)
	loaded_version := repo.get_version(library)

	// generate helper files
	generate_readme(binding_dir, library, loaded_version, typelib_path)
	generate_v_util(binding_dir)

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

// generate_readme generates README.md with binding metadata
fn generate_readme(binding_dir string, library string, version string, typelib_path string) {
	readme_path := os.join_path(binding_dir, 'README.md')

	readme_content := 'Library: ${library}
Version: ${version}
Typelib: ${typelib_path}
'

	os.write_file(readme_path, readme_content) or {
		eprintln('Error: Failed to write README.md')
		eprintln('${err}')
		exit(1)
	}
}

// generate_v_util generates helper functions for property access
fn generate_v_util(binding_dir string) {
	util_path := os.join_path(binding_dir, 'v_util.v')
	module_name := os.file_name(binding_dir)

	mut content := 'module ${module_name}

import edam.vgi

// helper functions for property access

fn get_bool_property(obj voidptr, prop_name string) bool {
	mut value := C.GValue{}
	C.g_value_init(&value, C.g_type_boolean)
	C.g_object_get_property(&C.GObject(obj), prop_name.str, &value)
	result := C.g_value_get_boolean(&value)
	C.g_value_unset(&value)
	return result
}

fn set_bool_property(obj voidptr, prop_name string, val bool) {
	mut gvalue := C.GValue{}
	C.g_value_init(&gvalue, C.g_type_boolean)
	C.g_value_set_boolean(&gvalue, val)
	C.g_object_set_property(&C.GObject(obj), prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_int_property(obj voidptr, prop_name string) int {
	mut value := C.GValue{}
	C.g_value_init(&value, C.g_type_int)
	C.g_object_get_property(&C.GObject(obj), prop_name.str, &value)
	result := C.g_value_get_int(&value)
	C.g_value_unset(&value)
	return result
}

fn set_int_property(obj voidptr, prop_name string, val int) {
	mut gvalue := C.GValue{}
	C.g_value_init(&gvalue, C.g_type_int)
	C.g_value_set_int(&gvalue, val)
	C.g_object_set_property(&C.GObject(obj), prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_uint_property(obj voidptr, prop_name string) u32 {
	mut value := C.GValue{}
	C.g_value_init(&value, C.g_type_uint)
	C.g_object_get_property(&C.GObject(obj), prop_name.str, &value)
	result := C.g_value_get_uint(&value)
	C.g_value_unset(&value)
	return result
}

fn set_uint_property(obj voidptr, prop_name string, val u32) {
	mut gvalue := C.GValue{}
	C.g_value_init(&gvalue, C.g_type_uint)
	C.g_value_set_uint(&gvalue, val)
	C.g_object_set_property(&C.GObject(obj), prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_int64_property(obj voidptr, prop_name string) i64 {
	mut value := C.GValue{}
	C.g_value_init(&value, C.g_type_int64)
	C.g_object_get_property(&C.GObject(obj), prop_name.str, &value)
	result := C.g_value_get_int64(&value)
	C.g_value_unset(&value)
	return result
}

fn set_int64_property(obj voidptr, prop_name string, val i64) {
	mut gvalue := C.GValue{}
	C.g_value_init(&gvalue, C.g_type_int64)
	C.g_value_set_int64(&gvalue, val)
	C.g_object_set_property(&C.GObject(obj), prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_uint64_property(obj voidptr, prop_name string) u64 {
	mut value := C.GValue{}
	C.g_value_init(&value, C.g_type_uint64)
	C.g_object_get_property(&C.GObject(obj), prop_name.str, &value)
	result := C.g_value_get_uint64(&value)
	C.g_value_unset(&value)
	return result
}

fn set_uint64_property(obj voidptr, prop_name string, val u64) {
	mut gvalue := C.GValue{}
	C.g_value_init(&gvalue, C.g_type_uint64)
	C.g_value_set_uint64(&gvalue, val)
	C.g_object_set_property(&C.GObject(obj), prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_float_property(obj voidptr, prop_name string) f32 {
	mut value := C.GValue{}
	C.g_value_init(&value, C.g_type_float)
	C.g_object_get_property(&C.GObject(obj), prop_name.str, &value)
	result := C.g_value_get_float(&value)
	C.g_value_unset(&value)
	return result
}

fn set_float_property(obj voidptr, prop_name string, val f32) {
	mut gvalue := C.GValue{}
	C.g_value_init(&gvalue, C.g_type_float)
	C.g_value_set_float(&gvalue, val)
	C.g_object_set_property(&C.GObject(obj), prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_double_property(obj voidptr, prop_name string) f64 {
	mut value := C.GValue{}
	C.g_value_init(&value, C.g_type_double)
	C.g_object_get_property(&C.GObject(obj), prop_name.str, &value)
	result := C.g_value_get_double(&value)
	C.g_value_unset(&value)
	return result
}

fn set_double_property(obj voidptr, prop_name string, val f64) {
	mut gvalue := C.GValue{}
	C.g_value_init(&gvalue, C.g_type_double)
	C.g_value_set_double(&gvalue, val)
	C.g_object_set_property(&C.GObject(obj), prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_string_property(obj voidptr, prop_name string) string {
	mut value := C.GValue{}
	C.g_value_init(&value, C.g_type_string)
	C.g_object_get_property(&C.GObject(obj), prop_name.str, &value)
	result := unsafe { cstring_to_vstring(C.g_value_get_string(&value)) }
	C.g_value_unset(&value)
	return result
}

fn set_string_property(obj voidptr, prop_name string, val string) {
	mut gvalue := C.GValue{}
	C.g_value_init(&gvalue, C.g_type_string)
	C.g_value_set_string(&gvalue, val.str)
	C.g_object_set_property(&C.GObject(obj), prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_pointer_property(obj voidptr, prop_name string) voidptr {
	mut value := C.GValue{}
	C.g_value_init(&value, C.g_type_pointer)
	C.g_object_get_property(&C.GObject(obj), prop_name.str, &value)
	result := C.g_value_get_pointer(&value)
	C.g_value_unset(&value)
	return result
}

fn set_pointer_property(obj voidptr, prop_name string, val voidptr) {
	mut gvalue := C.GValue{}
	C.g_value_init(&gvalue, C.g_type_pointer)
	C.g_value_set_pointer(&gvalue, val)
	C.g_object_set_property(&C.GObject(obj), prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}
'

	os.write_file(util_path, content) or {
		eprintln('Warning: Failed to write ${util_path}')
		return
	}
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

	// add writable properties only
	n_props := info.get_n_properties()
	for i in 0 .. int(n_props) {
		prop := info.get_property(u32(i)) or { continue }

		// only include writable properties (can be set in constructor)
		if !prop.is_writable() {
			prop.free()
			continue
		}

		prop_name := prop.get_name()

		// convert kebab-case to snake_case
		v_prop_name := prop_name.replace('-', '_')

		// get property type
		v_type := prop.get_v_type()

		content += '\t${v_prop_name} ?${v_type}\n'

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

		// get property type and helper name
		v_type := prop.get_v_type()
		helper := prop.get_property_helper_name()

		// getter if readable
		if prop.is_readable() {
			content += '// get_${v_prop_name} gets the ${prop_name} property\n'
			content += 'pub fn (obj &${object_name}) get_${v_prop_name}() ${v_type} {\n'
			content += '\treturn get_${helper}_property(obj.ptr, \'${prop_name}\')\n'
			content += '}\n\n'
		}

		// setter if writable
		if prop.is_writable() {
			content += '// set_${v_prop_name} sets the ${prop_name} property\n'
			content += 'pub fn (obj &${object_name}) set_${v_prop_name}(value ${v_type}) {\n'
			content += '\tset_${helper}_property(obj.ptr, \'${prop_name}\', value)\n'
			content += '}\n\n'
		}

		prop.free()
	}

	return content
}
