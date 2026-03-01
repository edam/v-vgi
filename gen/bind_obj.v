module gen

import os

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

	// generate C function declarations
	type_init := info.get_type_init()
	if type_init != '' {
		content += 'fn C.${type_init}() u64\n'
	}
	// add C.g_object_new declaration for constructor
	content += 'fn C.g_object_new(object_type u64, first_property_name &char) voidptr\n'
	content += generate_c_method_declarations(info)

	// struct with embedded parent (no implements clause)
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

// get_property_v_type returns the V type for a property that matches the helper function
fn get_property_v_type(prop PropertyInfo) string {
	helper := prop.get_property_helper_name()
	// map helper name to correct V type for the helper function parameter
	return match helper {
		'bool' { 'bool' }
		'int' { 'int' }
		'uint' { 'u32' }
		'int64' { 'i64' }
		'uint64' { 'u64' }
		'float' { 'f32' }
		'double' { 'f64' }
		'string' { 'string' }
		'pointer' { 'voidptr' }
		else { 'voidptr' }
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

		// get property type that matches the helper function
		v_type := get_property_v_type(prop)

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
	content += '\tobj := &${object_name}{ptr: unsafe { voidptr(obj_ptr) }}\n'

	// set each property if provided using property helpers
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
		helper := prop.get_property_helper_name()

		content += '\tif val := properties.${v_prop_name} {\n'
		content += '\t\tset_${helper}_property(obj.ptr, \'${prop_name}\', val)\n'
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
					'i8' { 'i8' }
					'u8' { 'u8' }
					'i16' { 'i16' }
					'u16' { 'u16' }
					'int', 'i32' { 'int' }
					'u32' { 'u32' }
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

		// add GError parameter if method can throw
		if method.can_throw_gerror() {
			c_params << 'error &&C.GError'
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
				'i8' { 'i8' }
				'u8' { 'u8' }
				'i16' { 'i16' }
				'u16' { 'u16' }
				'int', 'i32' { 'int' }
				'u32' { 'u32' }
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

	content += '\n'

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

		// skip low-level property methods (we generate typed accessors instead)
		if symbol == 'g_object_get_property' || symbol == 'g_object_set_property' {
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
			arg_name := sanitize_param_name(arg.get_name())
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
		can_throw := method.can_throw_gerror()

		// determine V return type (add ! for error-throwing methods)
		v_return_sig := if skip_return {
			if can_throw { '!' } else { '' }
		} else {
			if can_throw { '!${return_v_type}' } else { return_v_type }
		}

		// generate method signature
		content += 'pub fn (obj &${object_name}) ${v_method_name}(${param_list}) ${v_return_sig} {\n'

		if skip_return {
			// void return
			content += '\tC.${symbol}(obj.ptr'
			if call_args.len > 0 {
				content += ', ${call_args.join(', ')}'
			}
			if can_throw {
				content += ', unsafe { v_get_shared_error() }'
			}
			content += ')\n'
			if can_throw {
				content += '\tv_check_shared_error()!\n'
			}
		} else {
			// typed return
			if can_throw {
				content += '\tv_result := '
			} else {
				content += '\treturn '
			}
			if needs_string_conv {
				content += 'unsafe { cstring_to_vstring(C.${symbol}(obj.ptr'
			} else {
				content += 'C.${symbol}(obj.ptr'
			}
			if call_args.len > 0 {
				content += ', ${call_args.join(', ')}'
			}
			if can_throw {
				// don't wrap in unsafe if already in unsafe block
				if needs_string_conv {
					content += ', v_get_shared_error()'
				} else {
					content += ', unsafe { v_get_shared_error() }'
				}
			}
			if needs_string_conv {
				content += ')) }\n'
			} else {
				content += ')\n'
			}
			if can_throw {
				content += '\treturn v_check_shared_error_or_return(v_result)\n'
			}
		}
		content += '}\n\n'

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

	// also collect property accessor method names
	n_props := info.get_n_properties()
	for i in 0 .. int(n_props) {
		prop := info.get_property(u32(i)) or { continue }
		prop_name := prop.get_name()
		v_prop_name := prop_name.replace('-', '_')

		// track getter and setter names
		if prop.is_readable() {
			object_method_names['get_${v_prop_name}'] = true
		}
		if prop.is_writable() {
			object_method_names['set_${v_prop_name}'] = true
		}

		prop.free()
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
				arg_name := sanitize_param_name(arg.get_name())
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
			can_throw := method.can_throw_gerror()

			// determine V return type (add ! for error-throwing methods)
			v_return_sig := if skip_return {
				if can_throw { '!' } else { '' }
			} else {
				if can_throw { '!${return_v_type}' } else { return_v_type }
			}

			// generate method signature
			content += 'pub fn (obj &${object_name}) ${v_method_name}(${param_list}) ${v_return_sig} {\n'

			if skip_return {
				// void return
				content += '\tC.${symbol}(obj.ptr'
				if call_args.len > 0 {
					content += ', ${call_args.join(', ')}'
				}
				if can_throw {
					content += ', unsafe { v_get_shared_error() }'
				}
				content += ')\n'
				if can_throw {
					content += '\tv_check_shared_error()!\n'
				}
			} else {
				// typed return
				if can_throw {
					content += '\tv_result := '
				} else {
					content += '\treturn '
				}
				if needs_string_conv {
					content += 'unsafe { cstring_to_vstring(C.${symbol}(obj.ptr'
				} else {
					content += 'C.${symbol}(obj.ptr'
				}
				if call_args.len > 0 {
					content += ', ${call_args.join(', ')}'
				}
				if can_throw {
					content += ', unsafe { v_get_shared_error() }'
				}
				if needs_string_conv {
					content += ')) }\n'
				} else {
					content += ')\n'
				}
				if can_throw {
					content += '\treturn v_check_shared_error_or_return(v_result)\n'
				}
			}
			content += '}\n\n'

			method.free()
		}

		iface.free()
	}

	return content
}
