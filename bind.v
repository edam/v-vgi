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

// check_interface_signature_mismatches checks if object methods match interface signatures
fn check_interface_signature_mismatches(obj_info ObjectInfo, iface_info InterfaceInfo, object_name string) []string {
	mut mismatches := []string{}

	// build map of object methods: name -> (return_type, skip_return)
	mut obj_methods := map[string]struct {
		return_type string
		skip_return bool
	}{}

	n_obj_methods := obj_info.get_n_methods()
	for i in 0 .. int(n_obj_methods) {
		method := obj_info.get_method(u32(i)) or { continue }
		method_name := method.get_name().replace('-', '_')

		ret_type_info := method.get_return_type()
		obj_methods[method_name] = struct {
			return_type: ret_type_info.to_v_type()
			skip_return: method.skip_return()
		}
		ret_type_info.free()
		method.free()
	}

	// check each interface method
	iface_name := iface_info.get_name()
	n_iface_methods := iface_info.get_n_methods()

	for i in 0 .. int(n_iface_methods) {
		method := iface_info.get_method(u32(i)) or { continue }
		method_name := method.get_name().replace('-', '_')

		// skip private methods
		if method_name.starts_with('_') {
			method.free()
			continue
		}

		// get interface method signature
		ret_type_info := method.get_return_type()
		iface_ret_type := ret_type_info.to_v_type()
		iface_skip_return := method.skip_return()
		ret_type_info.free()

		// check if object has this method
		if method_name in obj_methods {
			obj_method := obj_methods[method_name]

			// compare return types
			obj_ret := if obj_method.skip_return { 'void' } else { obj_method.return_type }
			iface_ret := if iface_skip_return { 'void' } else { iface_ret_type }

			if obj_ret != iface_ret {
				mismatch := 'Method ${method_name}: interface expects return type ${iface_ret}, object has ${obj_ret}'
				mismatches << mismatch
			}
		}

		method.free()
	}

	return mismatches
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

	// get interfaces and check for cross-namespace
	n_interfaces := info.get_n_interfaces()
	mut implements_list := []string{}
	mut interface_comments := []string{}

	for i in 0 .. int(n_interfaces) {
		iface := info.get_interface(u32(i)) or { continue }
		iface_name := iface.get_name()
		iface_namespace := iface.get_namespace()

		// check for signature mismatches
		mismatches := check_interface_signature_mismatches(info, iface, object_name)

		if mismatches.len > 0 {
			// emit warning to stderr
			eprintln('Warning: ${object_name} claims to implement I${iface_name} but has signature mismatches:')
			for mismatch in mismatches {
				eprintln('  ${mismatch}')
			}

			// add comment to generated code
			mut comment := '// Note: ${object_name} claims to implement I${iface_name} but "implements" clause\n'
			comment += '// was omitted due to signature mismatches:\n'
			for mismatch in mismatches {
				comment += '// - ${mismatch}\n'
			}
			interface_comments << comment

			iface.free()
			continue
		}

		if iface_namespace != current_namespace {
			// cross-namespace interface - need import
			repo := get_default_repository()
			iface_version := repo.get_version(iface_namespace)
			iface_module := get_binding_dir_name(iface_namespace, iface_version)
			module_alias := iface_namespace.to_lower()

			// add import if not already present
			import_line := '\nimport edam.vgi.${iface_module} as ${module_alias}\n'
			if !content.contains(import_line) {
				content += import_line
			}
			implements_list << '${module_alias}.I${iface_name}'
		} else {
			// same namespace - direct reference
			implements_list << 'I${iface_name}'
		}

		iface.free()
	}

	content += '\n'

	// generate C function declarations
	type_init := info.get_type_init()
	if type_init != '' {
		content += 'fn C.${type_init}() u64\n'
	}
	content += generate_c_method_declarations(info)

	// add interface mismatch comments if any
	for comment in interface_comments {
		content += comment
	}

	// struct with embedded parent and implements clause
	if implements_list.len > 0 {
		content += 'pub struct ${object_name} implements ${implements_list.join(', ')} {\n'
	} else {
		content += 'pub struct ${object_name} {\n'
	}
	if parent_embed != '' {
		content += '\t${parent_embed}\n'
	} else {
		content += '\tptr voidptr\n'
	}
	content += '}\n\n'

	// properties struct
	content += generate_properties_struct(info, object_name, parent_name, parent_embed)

	// constructor
	content += generate_constructor(info, object_name)

	// property methods
	content += generate_property_methods(info, object_name)

	// object methods
	content += generate_object_methods(info, object_name)

	// interface implementations
	content += generate_object_interface_implementations(info, object_name)

	os.write_file(file_path, content) or {
		eprintln('Warning: Failed to write ${file_path}')
		return
	}
}

// generate_properties_struct generates @[params] properties struct
fn generate_properties_struct(info ObjectInfo, object_name string, parent_name string, parent_embed string) string {
	mut content := '@[params]\n'
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

// generate_constructor generates Object.new() constructor
fn generate_constructor(info ObjectInfo, object_name string) string {
	type_init := info.get_type_init()
	if type_init == '' {
		// no type init function, generate stub
		mut content := 'pub fn ${object_name}.new(properties ${object_name}Properties) &${object_name} {\n'
		content += '\tpanic("${object_name}.new() not yet implemented - no type init")\n'
		content += '}\n\n'
		return content
	}

	mut content := 'pub fn ${object_name}.new(properties ${object_name}Properties) &${object_name} {\n'
	content += '\tobj_ptr := C.g_object_new(C.${type_init}(), unsafe { nil })\n'
	content += '\tobj := &${object_name}{ptr: obj_ptr}\n'

	// set each property if provided
	n_props := info.get_n_properties()
	for i in 0 .. int(n_props) {
		prop := info.get_property(u32(i)) or { continue }

		// only writable properties are in the Properties struct
		if !prop.is_writable() {
			prop.free()
			continue
		}

		prop_name := prop.get_name()
		v_prop_name := prop_name.replace('-', '_')

		content += '\tif val := properties.${v_prop_name} {\n'
		content += '\t\tobj.set_${v_prop_name}(val)\n'
		content += '\t}\n'

		prop.free()
	}

	content += '\treturn obj\n'
	content += '}\n\n'
	return content
}

// generate_property_methods generates property getter/setter methods
fn generate_property_methods(info ObjectInfo, object_name string) string {
	mut content := ''

	// collect method names to avoid duplicates
	mut method_names := map[string]bool{}
	n_methods := info.get_n_methods()
	for i in 0 .. int(n_methods) {
		method := info.get_method(u32(i)) or { continue }
		method_name := method.get_name().replace('-', '_')
		method_names[method_name] = true
		method.free()
	}

	n_props := info.get_n_properties()
	for i in 0 .. int(n_props) {
		prop := info.get_property(u32(i)) or { continue }
		prop_name := prop.get_name()
		v_prop_name := prop_name.replace('-', '_')

		// get property type and helper name
		v_type := prop.get_v_type()
		helper := prop.get_property_helper_name()

		// getter if readable and no method exists
		if prop.is_readable() && 'get_${v_prop_name}' !in method_names {
			content += 'pub fn (obj &${object_name}) get_${v_prop_name}() ${v_type} {\n'
			content += '\treturn get_${helper}_property(obj.ptr, \'${prop_name}\')\n'
			content += '}\n\n'
		}

		// setter if writable and no method exists
		if prop.is_writable() && 'set_${v_prop_name}' !in method_names {
			content += 'pub fn (obj &${object_name}) set_${v_prop_name}(value ${v_type}) {\n'
			content += '\tset_${helper}_property(obj.ptr, \'${prop_name}\', value)\n'
			content += '}\n\n'
		}

		prop.free()
	}

	return content
}

// generate_c_method_declarations generates C function declarations for methods
fn generate_c_method_declarations(info ObjectInfo) string {
	mut content := ''
	mut has_methods := false

	n_methods := info.get_n_methods()
	for i in 0 .. int(n_methods) {
		method := info.get_method(u32(i)) or { continue }
		method_name := method.get_name()

		// skip private methods
		if method_name.starts_with('_') {
			method.free()
			continue
		}

		symbol := method.get_symbol()
		if symbol == '' {
			method.free()
			continue
		}

		has_methods = true

		// build C parameter list
		mut c_params := ['obj voidptr']
		n_args := method.get_n_args()

		for j in 0 .. int(n_args) {
			arg := method.get_arg(u32(j)) or { continue }
			direction := arg.get_direction()

			if direction == gi_direction_in {
				arg_type := arg.get_v_type()
				// convert V type to C type
				c_type := match arg_type {
					'string' { '&char' }
					'bool' { 'bool' }
					'int', 'i8', 'i16', 'i32' { 'int' }
					'u8', 'u16', 'u32' { 'u32' }
					'i64' { 'i64' }
					'u64' { 'u64' }
					'f32' { 'f32' }
					'f64' { 'f64' }
					else { 'voidptr' }
				}
				c_params << 'arg${j} ${c_type}'
			}

			arg.free()
		}

		// get return type
		return_type_info := method.get_return_type()
		return_v_type := return_type_info.to_v_type()
		return_type_info.free()

		skip_return := method.skip_return()

		c_return_type := if skip_return || return_v_type == 'voidptr' {
			'voidptr'
		} else {
			match return_v_type {
				'string' { '&char' }
				'bool' { 'bool' }
				'int', 'i8', 'i16' { 'int' }
				'u8', 'u16', 'u32' { 'u32' }
				'i64' { 'i64' }
				'u64' { 'u64' }
				'f32' { 'f32' }
				'f64' { 'f64' }
				else { 'voidptr' }
			}
		}

		content += 'fn C.${symbol}(${c_params.join(', ')}) ${c_return_type}\n'

		method.free()
	}

	if has_methods {
		content += '\n'
	}

	return content
}

// generate_object_methods generates object method bindings
fn generate_object_methods(info ObjectInfo, object_name string) string {
	mut content := ''

	n_methods := info.get_n_methods()
	for i in 0 .. int(n_methods) {
		method := info.get_method(u32(i)) or { continue }
		method_name := method.get_name()

		// skip private methods
		if method_name.starts_with('_') {
			method.free()
			continue
		}

		symbol := method.get_symbol()
		if symbol == '' {
			method.free()
			continue
		}

		// convert kebab-case to snake_case
		v_method_name := method_name.replace('-', '_')

		// build parameter list and call args
		mut params := []string{}
		mut call_args := []string{}
		n_args := method.get_n_args()

		for j in 0 .. int(n_args) {
			arg := method.get_arg(u32(j)) or { continue }
			arg_name := arg.get_name()
			arg_type := arg.get_v_type()
			direction := arg.get_direction()

			// only handle 'in' parameters for now
			if direction == gi_direction_in {
				params << '${arg_name} ${arg_type}'
				// convert V value to C value if needed
				call_arg := if arg_type == 'string' { '${arg_name}.str' } else { arg_name }
				call_args << call_arg
			}

			arg.free()
		}

		param_list := params.join(', ')

		// get return type
		return_type_info := method.get_return_type()
		return_v_type := return_type_info.to_v_type()
		return_type_info.free()

		skip_return := method.skip_return()
		needs_string_conv := return_v_type == 'string'

		// generate method signature
		if skip_return {
			// void return
			content += 'pub fn (obj &${object_name}) ${v_method_name}(${param_list}) {\n'
			content += '\tC.${symbol}(obj.ptr'
			if call_args.len > 0 {
				content += ', ${call_args.join(', ')}'
			}
			content += ')\n'
			content += '}\n\n'
		} else {
			// typed return
			content += 'pub fn (obj &${object_name}) ${v_method_name}(${param_list}) ${return_v_type} {\n'
			if needs_string_conv {
				content += '\treturn unsafe { cstring_to_vstring(C.${symbol}(obj.ptr'
			} else {
				content += '\treturn C.${symbol}(obj.ptr'
			}
			if call_args.len > 0 {
				content += ', ${call_args.join(', ')}'
			}
			if needs_string_conv {
				content += ')) }\n'
			} else {
				content += ')\n'
			}
			content += '}\n\n'
		}

		method.free()
	}

	return content
}

// generate_interface_binding generates V file for an interface
fn generate_interface_binding(info InterfaceInfo, binding_dir string) {
	interface_name := info.get_name()
	file_name := interface_name.to_lower() + '.v'
	file_path := os.join_path(binding_dir, file_name)
	module_name := os.file_name(binding_dir)

	mut content := 'module ${module_name}\n\n'

	// generate C method declarations
	content += generate_c_interface_method_declarations(info)

	// generate V interface (IFoo)
	content += 'pub interface I${interface_name} {\n'
	n_methods := info.get_n_methods()
	for i in 0 .. int(n_methods) {
		method := info.get_method(u32(i)) or { continue }
		method_name := method.get_name()

		// skip private methods
		if method_name.starts_with('_') {
			method.free()
			continue
		}

		v_method_name := method_name.replace('-', '_')

		// build parameter list
		mut params := []string{}
		n_args := method.get_n_args()
		for j in 0 .. int(n_args) {
			arg := method.get_arg(u32(j)) or { continue }
			direction := arg.get_direction()
			if direction == gi_direction_in {
				arg_name := arg.get_name()
				arg_type := arg.get_v_type()
				params << '${arg_name} ${arg_type}'
			}
			arg.free()
		}

		// get return type
		return_type_info := method.get_return_type()
		return_v_type := return_type_info.to_v_type()
		return_type_info.free()
		skip_return := method.skip_return()

		param_list := params.join(', ')

		if skip_return {
			content += '\t${v_method_name}(${param_list})\n'
		} else {
			content += '\t${v_method_name}(${param_list}) ${return_v_type}\n'
		}

		method.free()
	}
	content += '}\n\n'

	// generate concrete struct (Foo) for C interop
	content += 'pub struct ${interface_name} {\n'
	content += '\tptr voidptr\n'
	content += '}\n\n'

	// generate methods on concrete struct
	content += generate_interface_methods(info, interface_name)

	os.write_file(file_path, content) or {
		eprintln('Warning: Failed to write ${file_path}')
		return
	}
}

// generate_c_interface_method_declarations generates C function declarations for interface methods
fn generate_c_interface_method_declarations(info InterfaceInfo) string {
	mut content := ''
	mut has_methods := false

	n_methods := info.get_n_methods()
	for i in 0 .. int(n_methods) {
		method := info.get_method(u32(i)) or { continue }
		method_name := method.get_name()

		// skip private methods
		if method_name.starts_with('_') {
			method.free()
			continue
		}

		symbol := method.get_symbol()
		if symbol == '' {
			method.free()
			continue
		}

		has_methods = true

		// build C parameter list
		mut c_params := ['obj voidptr']
		n_args := method.get_n_args()

		for j in 0 .. int(n_args) {
			arg := method.get_arg(u32(j)) or { continue }
			direction := arg.get_direction()

			if direction == gi_direction_in {
				arg_type := arg.get_v_type()
				// convert V type to C type
				c_type := match arg_type {
					'string' { '&char' }
					'bool' { 'bool' }
					'int', 'i8', 'i16', 'i32' { 'int' }
					'u8', 'u16', 'u32' { 'u32' }
					'i64' { 'i64' }
					'u64' { 'u64' }
					'f32' { 'f32' }
					'f64' { 'f64' }
					else { 'voidptr' }
				}
				c_params << 'arg${j} ${c_type}'
			}

			arg.free()
		}

		// get return type
		return_type_info := method.get_return_type()
		return_v_type := return_type_info.to_v_type()
		return_type_info.free()

		skip_return := method.skip_return()

		c_return_type := if skip_return || return_v_type == 'voidptr' {
			'voidptr'
		} else {
			match return_v_type {
				'string' { '&char' }
				'bool' { 'bool' }
				'int', 'i8', 'i16' { 'int' }
				'u8', 'u16', 'u32' { 'u32' }
				'i64' { 'i64' }
				'u64' { 'u64' }
				'f32' { 'f32' }
				'f64' { 'f64' }
				else { 'voidptr' }
			}
		}

		content += 'fn C.${symbol}(${c_params.join(', ')}) ${c_return_type}\n'

		method.free()
	}

	if has_methods {
		content += '\n'
	}

	return content
}

// generate_interface_methods generates methods on the concrete interface struct
fn generate_interface_methods(info InterfaceInfo, interface_name string) string {
	mut content := ''

	n_methods := info.get_n_methods()
	for i in 0 .. int(n_methods) {
		method := info.get_method(u32(i)) or { continue }
		method_name := method.get_name()

		// skip private methods
		if method_name.starts_with('_') {
			method.free()
			continue
		}

		symbol := method.get_symbol()
		if symbol == '' {
			method.free()
			continue
		}

		// convert kebab-case to snake_case
		v_method_name := method_name.replace('-', '_')

		// build parameter list and call args
		mut params := []string{}
		mut call_args := []string{}
		n_args := method.get_n_args()

		for j in 0 .. int(n_args) {
			arg := method.get_arg(u32(j)) or { continue }
			arg_name := arg.get_name()
			arg_type := arg.get_v_type()
			direction := arg.get_direction()

			// only handle 'in' parameters for now
			if direction == gi_direction_in {
				params << '${arg_name} ${arg_type}'
				// convert V value to C value if needed
				call_arg := if arg_type == 'string' { '${arg_name}.str' } else { arg_name }
				call_args << call_arg
			}

			arg.free()
		}

		param_list := params.join(', ')

		// get return type
		return_type_info := method.get_return_type()
		return_v_type := return_type_info.to_v_type()
		return_type_info.free()

		skip_return := method.skip_return()
		needs_string_conv := return_v_type == 'string'

		// generate method signature
		if skip_return {
			// void return
			content += 'pub fn (obj &${interface_name}) ${v_method_name}(${param_list}) {\n'
			content += '\tC.${symbol}(obj.ptr'
			if call_args.len > 0 {
				content += ', ${call_args.join(', ')}'
			}
			content += ')\n'
			content += '}\n\n'
		} else {
			// typed return
			content += 'pub fn (obj &${interface_name}) ${v_method_name}(${param_list}) ${return_v_type} {\n'
			if needs_string_conv {
				content += '\treturn unsafe { cstring_to_vstring(C.${symbol}(obj.ptr'
			} else {
				content += '\treturn C.${symbol}(obj.ptr'
			}
			if call_args.len > 0 {
				content += ', ${call_args.join(', ')}'
			}
			if needs_string_conv {
				content += ')) }\n'
			} else {
				content += ')\n'
			}
			content += '}\n\n'
		}

		method.free()
	}

	return content
}

// generate_object_interface_implementations generates interface method implementations on an object
fn generate_object_interface_implementations(info ObjectInfo, object_name string) string {
	mut content := ''

	n_interfaces := info.get_n_interfaces()
	if n_interfaces == 0 {
		return content
	}

	// collect all method names from the object itself to detect collisions
	mut object_method_names := map[string]bool{}
	n_object_methods := info.get_n_methods()
	for i in 0 .. int(n_object_methods) {
		method := info.get_method(u32(i)) or { continue }
		method_name := method.get_name()
		v_method_name := method_name.replace('-', '_')
		object_method_names[v_method_name] = true
		method.free()
	}

	for i in 0 .. int(n_interfaces) {
		iface := info.get_interface(u32(i)) or { continue }
		iface_name := iface.get_name()

		content += '// ${iface_name} interface methods\n'

		// generate each interface method on the object
		n_methods := iface.get_n_methods()
		for j in 0 .. int(n_methods) {
			method := iface.get_method(u32(j)) or { continue }
			method_name := method.get_name()

			// skip private methods
			if method_name.starts_with('_') {
				method.free()
				continue
			}

			symbol := method.get_symbol()
			if symbol == '' {
				method.free()
				continue
			}

			// convert kebab-case to snake_case
			v_method_name := method_name.replace('-', '_')

			// skip if object already has a method with this name
			if v_method_name in object_method_names {
				method.free()
				continue
			}

			// build parameter list and call args
			mut params := []string{}
			mut call_args := []string{}
			n_args := method.get_n_args()

			for k in 0 .. int(n_args) {
				arg := method.get_arg(u32(k)) or { continue }
				arg_name := arg.get_name()
				arg_type := arg.get_v_type()
				direction := arg.get_direction()

				// only handle 'in' parameters for now
				if direction == gi_direction_in {
					params << '${arg_name} ${arg_type}'
					// convert V value to C value if needed
					call_arg := if arg_type == 'string' { '${arg_name}.str' } else { arg_name }
					call_args << call_arg
				}

				arg.free()
			}

			param_list := params.join(', ')

			// get return type
			return_type_info := method.get_return_type()
			return_v_type := return_type_info.to_v_type()
			return_type_info.free()

			skip_return := method.skip_return()
			needs_string_conv := return_v_type == 'string'

			// generate method signature
			if skip_return {
				// void return
				content += 'pub fn (obj &${object_name}) ${v_method_name}(${param_list}) {\n'
				content += '\tC.${symbol}(obj.ptr'
				if call_args.len > 0 {
					content += ', ${call_args.join(', ')}'
				}
				content += ')\n'
				content += '}\n\n'
			} else {
				// typed return
				content += 'pub fn (obj &${object_name}) ${v_method_name}(${param_list}) ${return_v_type} {\n'
				if needs_string_conv {
					content += '\treturn unsafe { cstring_to_vstring(C.${symbol}(obj.ptr'
				} else {
					content += '\treturn C.${symbol}(obj.ptr'
				}
				if call_args.len > 0 {
					content += ', ${call_args.join(', ')}'
				}
				if needs_string_conv {
					content += ')) }\n'
				} else {
					content += ')\n'
				}
				content += '}\n\n'
			}

			method.free()
		}

		iface.free()
	}

	return content
}

// generate_enum_binding generates V enum/flags from EnumInfo
fn generate_enum_binding(info EnumInfo, binding_dir string) {
	enum_name := info.get_name()
	file_name := enum_name.to_lower() + '.v'
	file_path := os.join_path(binding_dir, file_name)

	mut content := 'module ${os.file_name(binding_dir)}\n\n'

	// determine if this is flags or enum based on type
	info_type := info.get_type()
	is_flags := info_type == 'flags'

	// generate enum definition
	if is_flags {
		content += '@[flag]\n'
	}
	content += 'pub enum ${enum_name} {\n'

	// generate enum values
	n_values := info.get_n_values()
	for i in 0 .. int(n_values) {
		value_info := info.get_value(u32(i)) or { continue }
		value_name := value_info.get_name()
		value_int := value_info.get_value()

		// convert name to snake_case for V enum convention
		// e.g., GTK_ALIGN_FILL -> align_fill
		mut v_name := value_name.to_lower().replace('-', '_')

		// prefix with underscore if name starts with digit
		if v_name.len > 0 && v_name[0].is_digit() {
			v_name = '_' + v_name
		}

		// for flags, don't specify values (V auto-assigns power of 2)
		// for enums, include explicit values
		if is_flags {
			content += '\t${v_name}\n'
		} else {
			content += '\t${v_name} = ${value_int}\n'
		}

		value_info.free()
	}

	content += '}\n'

	// write file
	os.write_file(file_path, content) or {
		eprintln('Failed to write ${file_path}: ${err}')
		return
	}
}
